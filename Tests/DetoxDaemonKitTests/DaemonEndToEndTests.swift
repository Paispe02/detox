import DetoxCore
import DetoxIPC
import Foundation
import Testing
@testable import DetoxDaemonKit

final class FakeTime: TimeSource, NetworkTimeFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var wall: Date
    private var mono: TimeInterval = 1000
    init(_ start: Date) { wall = start }
    func readings() -> (monotonic: TimeInterval, wall: Date) { lock.lock(); defer { lock.unlock() }; return (mono, wall) }
    func advance(_ s: TimeInterval) { lock.lock(); wall += s; mono += s; lock.unlock() }
    func fetch(_ completion: @escaping (Date?) -> Void) { completion(readings().wall) }
}

private func madridDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Madrid")!
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func youtubeDraft(_ lock: LockDraft = .password("1234"), services: Set<ServiceID> = [.youtube]) -> BlockDraft {
    BlockDraft(name: "Noches", targets: BlockTargets(services: services),
               window: DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)), weekdays: Set(Weekday.allCases),
               startDate: LocalDate(2026, 12, 1), endDate: LocalDate(2026, 12, 31),
               timeZoneID: "Europe/Madrid", lock: lock, pauseMinutes: 15)
}

private struct Harness {
    let root: URL
    let time: FakeTime
    var paths: DaemonPaths { DaemonPaths.testing(root: root) }
    var client: DetoxClient { DetoxClient(socketPath: paths.socketPath) }
    func hosts() -> String { (try? String(contentsOfFile: paths.hostsPath, encoding: .utf8)) ?? "" }
    func makeDaemon() throws -> Daemon {
        let d = Daemon(paths: paths, dryRun: true, timeSource: time, networkTime: time)
        try d.start()
        return d
    }
    init(at start: Date) {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dx-\(UUID().uuidString.prefix(8))")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        time = FakeTime(start)
    }
}

private func firstEvent(_ stream: AsyncThrowingStream<DaemonEvent, Error>, matching: @escaping @Sendable (DaemonEvent) -> Bool,
                        trigger: () async throws -> Void) async throws -> DaemonEvent? {
    try await withThrowingTaskGroup(of: DaemonEvent?.self) { group in
        group.addTask { for try await e in stream where matching(e) { return e }; return nil }
        group.addTask { try await Task.sleep(nanoseconds: 2_000_000_000); return nil }
        try await Task.sleep(nanoseconds: 200_000_000)
        try await trigger()
        let r = try await group.next()!
        group.cancelAll()
        return r
    }
}

@Test func blockUnlockAndPauseExpiry() async throws {
    let h = Harness(at: madridDate(2026, 12, 2, 23, 0))
    let daemon = try h.makeDaemon()
    defer { daemon.stop() }

    let created = try await h.client.send(.createBlock(youtubeDraft()))
    guard case .block(let view) = created else { Issue.record("\(created)"); return }
    #expect(view.phase == .active)
    #expect(h.hosts().contains("127.0.0.1\twww.youtube.com"))

    let wrong = try await h.client.send(.unlock(blockID: view.id, credential: .password("0000"), action: .pause))
    guard case .failure(.wrongCredential) = wrong else { Issue.record("\(wrong)"); return }

    let right = try await h.client.send(.unlock(blockID: view.id, credential: .password("1234"), action: .pause))
    guard case .block(let paused) = right else { Issue.record("\(right)"); return }
    #expect(paused.phase == .paused)
    #expect(!h.hosts().contains("youtube"))

    let event = try await firstEvent(h.client.events(), matching: { if case .pauseEnded = $0 { return true }; return false }) {
        h.time.advance(16 * 60)
        daemon.tick()
    }
    #expect(h.hosts().contains("127.0.0.1\twww.youtube.com"))
    guard case .pauseEnded(_, let domains) = event else { Issue.record("no pauseEnded"); return }
    #expect(domains.contains("www.youtube.com"))
}

@Test func restartAppliesHostsImmediately() async throws {
    let h = Harness(at: madridDate(2026, 12, 2, 23, 0))
    let first = try h.makeDaemon()
    _ = try await h.client.send(.createBlock(youtubeDraft()))
    first.stop()
    try "".write(toFile: h.paths.hostsPath, atomically: true, encoding: .utf8)

    let second = try h.makeDaemon()
    defer { second.stop() }
    #expect(h.hosts().contains("# BEGIN DETOX"))
}

@Test func timeJumpAcrossWindowStartEmitsWindowStarted() async throws {
    let h = Harness(at: madridDate(2026, 12, 2, 22, 0))
    let daemon = try h.makeDaemon()
    defer { daemon.stop() }
    _ = try await h.client.send(.createBlock(youtubeDraft()))
    #expect(!h.hosts().contains("youtube"))
    let event = try await firstEvent(h.client.events(), matching: { if case .windowStarted = $0 { return true }; return false }) {
        h.time.advance(3600)
        daemon.tick()
    }
    guard case .windowStarted(_, let domains) = event else { Issue.record("no windowStarted"); return }
    #expect(domains.contains("www.youtube.com"))
}

@Test func looseningOverSocketIsRejected() async throws {
    let h = Harness(at: madridDate(2026, 12, 2, 12, 0))
    let daemon = try h.makeDaemon()
    defer { daemon.stop() }
    guard case .block(let v) = try await h.client.send(.createBlock(youtubeDraft(services: [.youtube, .instagram]))) else {
        Issue.record("create failed"); return
    }
    let r = try await h.client.send(.updateBlock(id: v.id, draft: youtubeDraft(.unchanged, services: [.youtube])))
    guard case .failure(let e) = r else { Issue.record("\(r)"); return }
    #expect(e == .tightening([.removesTargets]))
}

@Test func blockedHostProducesAttemptEvent() async throws {
    let h = Harness(at: madridDate(2026, 12, 2, 23, 0))
    let daemon = try h.makeDaemon()
    defer { daemon.stop() }
    _ = try await h.client.send(.createBlock(youtubeDraft()))
    let event = try await firstEvent(h.client.events(), matching: { if case .attempt = $0 { return true }; return false }) {
        daemon.handleHost("www.youtube.com")
        daemon.handleHost("www.wikipedia.org")
    }
    guard case .attempt(let a) = event else { Issue.record("no attempt"); return }
    #expect(a.target == .domain("www.youtube.com") && a.isPrimaryDomain && a.blockNames == ["Noches"])
}

@Test func friendRegistrationReturnsURIOnce() async throws {
    let h = Harness(at: madridDate(2026, 12, 2, 12, 0))
    let daemon = try h.makeDaemon()
    defer { daemon.stop() }
    let r = try await h.client.send(.registerFriend(name: "Ana"))
    guard case .friendProvisioning(let p) = r else { Issue.record("\(r)"); return }
    #expect(p.uri.hasPrefix("otpauth://totp/Detox:Ana?secret="))
    guard case .status(let s) = try await h.client.send(.status) else { Issue.record("status"); return }
    #expect(s.friends.map(\.name) == ["Ana"] && !s.friends[0].isConfirmed)
}
