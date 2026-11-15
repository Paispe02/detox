import Foundation

public enum LockDraft: Codable, Hashable, Sendable {
    case noExit
    case password(String)
    case friend(UUID)
    /// Keep the block's current lock (editing only).
    case unchanged
}

public struct BlockDraft: Codable, Hashable, Sendable {
    public var name: String
    public var targets: BlockTargets
    public var window: DailyWindow
    public var weekdays: Set<Weekday>
    public var startDate: LocalDate
    public var endDate: LocalDate
    public var timeZoneID: String
    public var lock: LockDraft
    public var pauseMinutes: Int

    public init(name: String, targets: BlockTargets, window: DailyWindow, weekdays: Set<Weekday>,
                startDate: LocalDate, endDate: LocalDate, timeZoneID: String, lock: LockDraft, pauseMinutes: Int) {
        self.name = name
        self.targets = targets
        self.window = window
        self.weekdays = weekdays
        self.startDate = startDate
        self.endDate = endDate
        self.timeZoneID = timeZoneID
        self.lock = lock
        self.pauseMinutes = pauseMinutes
    }
}

public enum UnlockCredential: Codable, Hashable, Sendable {
    case password(String)
    case friendCode(String)
}

public enum UnlockAction: String, Codable, Sendable {
    case pause, cancel
}

public enum CommandError: Error, Codable, Equatable, Sendable {
    case notFound
    case invalid(String)
    case tightening([TighteningViolation])
    case notDeletable
    case noExit(endsAt: Date)
    case notActive
    case wrongCredential
    case rateLimited(until: Date)
    case cancelRequiresFriend
    case friendInUse
    case friendNotConfirmed
    case unknownFriend
    case daemonUnavailable
}

public struct DetoxState: Codable, Equatable, Sendable {
    public var version = 1
    public var blocks: [Block] = []
    public var friends: [FriendKey] = []
    public var limiter = AttemptLimiter()
    /// High-water mark of network-verified time. While the clock is untrusted (offline after a reboot),
    /// time never goes behind it, so setting the clock back can't make a running block deletable.
    public var lastTrustedTime: Date?

    public init() {}

    public func effectiveNow(wall: Date, isTrusted: Bool) -> Date {
        guard !isTrusted, let last = lastTrustedTime else { return wall }
        return max(wall, last)
    }
}

/// Apps that must never be terminated: killing them breaks the Mac or Detox itself.
let protectedBundleIDs: Set<String> = [
    "com.apple.loginwindow", "com.apple.finder", "com.apple.dock", "com.apple.systemuiserver",
    "com.apple.WindowServer", "com.apple.controlcenter", "com.apple.Terminal", "com.apple.ActivityMonitor",
    "com.apple.systempreferences", "com.detox.app",
]
let protectedPathPrefixes = ["/System/", "/usr/", "/bin/", "/sbin/", "/Library/PrivilegedHelperTools/", "/private/", "/dev/"]

/// The daemon kills processes as root by bundle path, so an AppTarget must be a real, ordinary .app.
func isAcceptableApp(_ a: AppTarget) -> Bool {
    let path = (a.path as NSString).standardizingPath
    guard path.hasPrefix("/"), path.hasSuffix(".app"), path == a.path,
          !protectedPathPrefixes.contains(where: { (path + "/").hasPrefix($0) }),
          !protectedBundleIDs.contains(a.bundleID) else { return false }
    guard let info = NSDictionary(contentsOfFile: path + "/Contents/Info.plist"),
          let id = info["CFBundleIdentifier"] as? String else { return false }
    return id == a.bundleID && !protectedBundleIDs.contains(id)
}

public let pauseRange = 5...60

extension DetoxState {
    private func index(of id: UUID) throws -> Int {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { throw CommandError.notFound }
        return i
    }

    /// Validates a draft and turns it into a block. `currentLock` resolves `.unchanged`.
    private func build(_ d: BlockDraft, id: UUID, currentLock: Lock?, now: Date) throws -> Block {
        let name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CommandError.invalid("nombre") }
        guard !d.targets.isEmpty else { throw CommandError.invalid("objetivos") }
        guard !d.weekdays.isEmpty else { throw CommandError.invalid("días") }
        guard let tz = TimeZone(identifier: d.timeZoneID) else { throw CommandError.invalid("zona horaria") }
        guard d.startDate <= d.endDate, d.endDate >= LocalDate.containing(now, in: tz) else {
            throw CommandError.invalid("fechas")
        }
        var domains = Set<String>()
        for raw in d.targets.domains {
            guard let n = DomainNormalizer.normalize(raw) else { throw CommandError.invalid("dominio: \(raw)") }
            domains.insert(n)
        }
        for app in d.targets.apps where !isAcceptableApp(app) {
            throw CommandError.invalid("app: \(app.name)")
        }
        let lock: Lock
        switch d.lock {
        case .noExit:
            lock = .noExit
        case .password(let pw):
            guard pw.count >= 4 else { throw CommandError.invalid("contraseña") }
            if case .password(let h) = currentLock, h.verify(pw) { lock = .password(h) }
            else { lock = .password(.make(password: pw)) }
        case .friend(let fid):
            guard let f = friends.first(where: { $0.id == fid }) else { throw CommandError.unknownFriend }
            guard f.isConfirmed else { throw CommandError.friendNotConfirmed }
            lock = .friend(fid)
        case .unchanged:
            guard let current = currentLock else { throw CommandError.invalid("cerradura") }
            lock = current
        }
        if lock != .noExit && !pauseRange.contains(d.pauseMinutes) { throw CommandError.invalid("pausa") }
        var targets = d.targets
        targets.domains = domains
        return Block(id: id, name: name, targets: targets, window: d.window, weekdays: d.weekdays,
                     startDate: d.startDate, endDate: d.endDate, timeZoneID: d.timeZoneID, lock: lock,
                     pauseMinutes: d.pauseMinutes, pausedUntil: nil, cancelledAt: nil)
    }

    public mutating func createBlock(_ d: BlockDraft, now: Date, isTrustedTime: Bool) throws -> Block {
        let b = try build(d, id: UUID(), currentLock: nil, now: now)
        blocks.append(b)
        return b
    }

    public mutating func updateBlock(id: UUID, with d: BlockDraft, now: Date, isTrustedTime: Bool) throws -> Block {
        let i = try index(of: id)
        let old = blocks[i]
        switch old.phase(at: now, isTrustedTime: isTrustedTime) {
        case .finished:
            throw CommandError.invalid("terminado")
        case .scheduled:
            blocks[i] = try build(d, id: id, currentLock: old.lock, now: now)
        case .running, .active, .paused:
            var new = try build(d, id: id, currentLock: old.lock, now: now)
            // A friend registered after the commitment began can't take over its lock:
            // otherwise a self-registered "friend" turns a pause-only password lock into a cancellable one.
            if case .friend(let fid) = new.lock, new.lock != old.lock,
               let f = friends.first(where: { $0.id == fid }), f.createdAt >= old.commitmentInterval.start {
                throw CommandError.invalid("amigo reciente")
            }
            new.pausedUntil = old.pausedUntil
            new.cancelledAt = old.cancelledAt
            let v = tighteningViolations(from: old, to: new)
            guard v.isEmpty else { throw CommandError.tightening(v) }
            blocks[i] = new
        }
        return blocks[i]
    }

    public mutating func deleteBlock(id: UUID, now: Date, isTrustedTime: Bool) throws {
        let i = try index(of: id)
        switch blocks[i].phase(at: now, isTrustedTime: isTrustedTime) {
        case .scheduled, .finished: blocks.remove(at: i)
        default: throw CommandError.notDeletable
        }
    }

    public mutating func unlock(blockID: UUID, credential: UnlockCredential, action: UnlockAction,
                                now: Date, isTrustedTime: Bool) throws -> Block {
        if limiter.isLocked(at: now), let until = limiter.lockedUntil { throw CommandError.rateLimited(until: until) }
        let i = try index(of: blockID)
        let b = blocks[i]
        if b.lock == .noExit { throw CommandError.noExit(endsAt: b.commitmentInterval.end) }
        guard b.phase(at: now, isTrustedTime: isTrustedTime) == .active else { throw CommandError.notActive }

        var ok = false
        switch (b.lock, credential) {
        case (.password(let h), .password(let pw)):
            ok = h.verify(pw)
        case (.friend(let fid), .friendCode(let code)):
            if let fi = friends.firstIndex(where: { $0.id == fid }) { ok = friends[fi].consume(code: code, at: now) }
        default:
            ok = false
        }
        guard ok else {
            limiter.recordFailure(at: now)
            throw CommandError.wrongCredential
        }
        limiter.recordSuccess()
        switch action {
        case .pause:
            blocks[i].pausedUntil = now.addingTimeInterval(TimeInterval(b.pauseMinutes * 60))
        case .cancel:
            guard case .friend = b.lock else { throw CommandError.cancelRequiresFriend }
            blocks[i].cancelledAt = now
        }
        return blocks[i]
    }

    public mutating func registerFriend(name: String, now: Date) throws -> FriendKey {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw CommandError.invalid("nombre") }
        let f = FriendKey.generate(name: clean, now: now)
        friends.append(f)
        return f
    }

    public mutating func confirmFriend(id: UUID, code: String, now: Date) throws {
        guard let i = friends.firstIndex(where: { $0.id == id }) else { throw CommandError.unknownFriend }
        guard friends[i].consume(code: code, at: now) else { throw CommandError.wrongCredential }
        friends[i].isConfirmed = true
    }

    public mutating func deleteFriend(id: UUID, now: Date, isTrustedTime: Bool) throws {
        guard let i = friends.firstIndex(where: { $0.id == id }) else { throw CommandError.unknownFriend }
        let inUse = blocks.contains { $0.lock == .friend(id) && $0.phase(at: now, isTrustedTime: isTrustedTime) != .finished }
        if inUse { throw CommandError.friendInUse }
        friends.remove(at: i)
    }
}
