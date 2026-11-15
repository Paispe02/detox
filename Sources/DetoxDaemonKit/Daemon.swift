import DetoxCore
import DetoxIPC
import Foundation

public struct DaemonPaths: Sendable {
    public var stateURL: URL
    public var socketPath: String
    public var hostsPath: String
    public var chromePolicyPath: String

    public static let production = DaemonPaths(
        stateURL: URL(fileURLWithPath: "/Library/Application Support/Detox/state.json"),
        socketPath: "/var/run/detox.sock",
        hostsPath: "/etc/hosts",
        chromePolicyPath: "/Library/Managed Preferences/com.google.Chrome.plist")

    public static func testing(root: URL) -> DaemonPaths {
        DaemonPaths(stateURL: root.appendingPathComponent("state/state.json"),
                    socketPath: root.appendingPathComponent("detox.sock").path,
                    hostsPath: root.appendingPathComponent("hosts").path,
                    chromePolicyPath: root.appendingPathComponent("chrome.plist").path)
    }
}

public protocol TimeSource {
    func readings() -> (monotonic: TimeInterval, wall: Date)
}

public struct SystemTime: TimeSource {
    public init() {}
    public func readings() -> (monotonic: TimeInterval, wall: Date) { (MonotonicClock.now(), Date()) }
}

/// The single source of truth. All state lives on `queue`.
public final class Daemon {
    public static let tickInterval: TimeInterval = 2

    private let paths: DaemonPaths
    private let dryRun: Bool
    private let timeSource: TimeSource
    private let networkTime: NetworkTimeFetching
    private let queue = DispatchQueue(label: "com.detox.daemon.state")
    private let store: StateStore
    private let enforcer: Enforcer
    private var server: IPCServer?
    private var listener: InterceptListener?
    private var timer: DispatchSourceTimer?

    private var state = DetoxState()
    private var clock = TrustedClock()
    private var fetchingTime = false
    private var plan = EnforcementPlan()
    private var phases: [UUID: BlockPhase] = [:]
    private var tickCount = 0

    public init(paths: DaemonPaths, dryRun: Bool, timeSource: TimeSource = SystemTime(),
                networkTime: NetworkTimeFetching = AppleNetworkTime()) {
        self.paths = paths
        self.dryRun = dryRun
        self.timeSource = timeSource
        self.networkTime = networkTime
        self.store = StateStore(url: paths.stateURL)
        let runner: CommandRunning = dryRun ? RecordingCommandRunner() : ProcessCommandRunner()
        let signal: (pid_t, Int32) -> Int32 = dryRun ? { _, _ in 0 } : { Darwin.kill($0, $1) }
        enforcer = Enforcer(hosts: HostsFile(path: paths.hostsPath, runner: runner, flushesDNS: !dryRun),
                            packetFilter: PacketFilter(runner: runner),
                            chromePolicy: ChromePolicy(plistPath: paths.chromePolicyPath),
                            terminator: ProcessTerminator(listing: LibprocProcessListing(), signal: signal),
                            resolveApp: { AppResolver.bundlePath(forBundleID: $0) })
        queue.setSpecific(key: Self.onQueueKey, value: true)
    }

    // MARK: lifecycle

    public func start() throws {
        try queue.sync {
            state = try store.load()
            if !dryRun { enforcer.resetFirewall() }
            requestNetworkTime()
            tickLocked()
        }
        let server = IPCServer(socketPath: paths.socketPath, queue: queue) { [weak self] req in
            self?.handle(req) ?? .failure(.daemonUnavailable)
        }
        try server.start()
        self.server = server
        if !dryRun {
            let l = InterceptListener(endpoints: ListenEndpoint.production, deliverOn: queue) { [weak self] host in
                self?.handleHostLocked(host)
            }
            for ep in l.start() { log("no se pudo escuchar en \(ep.address):\(ep.port)") }
            listener = l
        }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + Self.tickInterval, repeating: Self.tickInterval)
        t.setEventHandler { [weak self] in self?.tickLocked() }
        t.resume()
        timer = t
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        listener?.stop()
        server?.stop()
        queue.sync {}
    }

    public func cleanupSystem() {
        enforcer.cleanup()
    }

    // MARK: time

    private func now() -> (date: Date, isTrusted: Bool) {
        let r = timeSource.readings()
        let t = clock.now(monotonic: r.monotonic, wallClock: r.wall)
        return (state.effectiveNow(wall: t.date, isTrusted: t.isTrusted), t.isTrusted)
    }

    /// Persist the trusted-time high-water mark about once a minute.
    private func recordTrustedTime(_ date: Date) {
        if let last = state.lastTrustedTime, date.timeIntervalSince(last) < 60 { return }
        state.lastTrustedTime = date
        do { try store.save(state) } catch { log("no se pudo guardar el estado: \(error)") }
    }

    private func requestNetworkTime() {
        guard !fetchingTime else { return }
        fetchingTime = true
        let mono = timeSource.readings().monotonic
        networkTime.fetch { [weak self] date in
            guard let self else { return }
            let apply = {
                self.fetchingTime = false
                if let date { self.clock.anchor(networkTime: date, monotonic: mono) }
            }
            if DispatchQueue.getSpecific(key: Self.onQueueKey) == true { apply() }
            else { self.queue.async { apply(); self.tickLocked() } }
        }
    }

    private static let onQueueKey = DispatchSpecificKey<Bool>()

    // MARK: tick

    public func tick() {
        queue.sync { tickLocked() }
    }

    private func tickLocked() {
        tickCount += 1
        let (date, trusted) = now()
        if trusted { recordTrustedTime(date) }
        if clock.needsReanchor(monotonic: timeSource.readings().monotonic) { requestNetworkTime() }
        let newPlan = makeEnforcementPlan(blocks: state.blocks, now: date, isTrustedTime: trusted)
        var newPhases: [UUID: BlockPhase] = [:]
        for b in state.blocks { newPhases[b.id] = b.phase(at: date, isTrustedTime: trusted) }
        let running = newPhases.values.contains { $0 == .running || $0 == .active || $0 == .paused }
        let hits = enforcer.apply(plan: newPlan, anyBlockRunning: running, tick: tickCount)
        let events = transitionEvents(previous: phases, current: newPhases, plan: newPlan)
        let phaseChanged = newPhases != phases && !phases.isEmpty
        plan = newPlan
        phases = newPhases
        events.forEach { server?.broadcast($0) }
        if phaseChanged { server?.broadcast(.stateChanged) }
        for hit in hits {
            let name = URL(fileURLWithPath: hit.bundlePath).deletingPathExtension().lastPathComponent
            server?.broadcast(.attempt(AttemptEvent(target: .app(bundleID: hit.bundleID, name: name),
                                                    blockIDs: Array(hit.blockIDs), blockNames: names(hit.blockIDs),
                                                    isPrimaryDomain: false, at: date)))
        }
    }

    private func names(_ ids: Set<UUID>) -> [String] {
        state.blocks.filter { ids.contains($0.id) }.map(\.name)
    }

    // MARK: attempts

    /// Test entry point; production calls arrive on the queue from the listener.
    public func handleHost(_ host: String) {
        queue.sync { handleHostLocked(host) }
    }

    private func handleHostLocked(_ host: String) {
        guard let ids = plan.blockedDomains[host] else { return }
        server?.broadcast(.attempt(AttemptEvent(target: .domain(host), blockIDs: Array(ids), blockNames: names(ids),
                                                isPrimaryDomain: plan.primaryDomains.contains(host), at: now().date)))
    }

    // MARK: requests (on queue)

    private func handle(_ req: Request) -> Response {
        let (date, trusted) = now()
        do {
            switch req {
            case .ping:
                return .pong
            case .subscribe:
                return .ok
            case .status:
                return .status(state.snapshot(now: date, isTrustedTime: trusted))
            case .createBlock(let d):
                let b = try mutate { try $0.createBlock(d, now: date, isTrustedTime: trusted) }
                return .block(state.view(of: b, now: date, isTrustedTime: trusted))
            case .updateBlock(let id, let d):
                let b = try mutate { try $0.updateBlock(id: id, with: d, now: date, isTrustedTime: trusted) }
                return .block(state.view(of: b, now: date, isTrustedTime: trusted))
            case .deleteBlock(let id):
                try mutate { try $0.deleteBlock(id: id, now: date, isTrustedTime: trusted) }
                return .ok
            case .unlock(let id, let cred, let action):
                let b = try mutate { try $0.unlock(blockID: id, credential: cred, action: action, now: date, isTrustedTime: trusted) }
                return .block(state.view(of: b, now: date, isTrustedTime: trusted))
            case .registerFriend(let name):
                let f = try mutate { try $0.registerFriend(name: name, now: date) }
                return .friendProvisioning(FriendProvisioning(friendID: f.id, name: f.name, uri: f.provisioningURI))
            case .confirmFriend(let id, let code):
                try mutate { try $0.confirmFriend(id: id, code: code, now: date) }
                return .ok
            case .deleteFriend(let id):
                try mutate { try $0.deleteFriend(id: id, now: date, isTrustedTime: trusted) }
                return .ok
            }
        } catch let e as CommandError {
            return .failure(e)
        } catch {
            log("error: \(error)")
            return .failure(.invalid("interno"))
        }
    }

    /// Runs a state command. On failure the limiter changes (failed attempts) are still persisted.
    @discardableResult
    private func mutate<T>(_ body: (inout DetoxState) throws -> T) throws -> T {
        var copy = state
        defer {
            if copy != state {
                state = copy
                do { try store.save(state) } catch { log("no se pudo guardar el estado: \(error)") }
                tickLocked()
                server?.broadcast(.stateChanged)
            }
        }
        return try body(&copy)
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("detoxd: \(message)\n".utf8))
    }
}
