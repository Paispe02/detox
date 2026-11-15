import DetoxCore
import Foundation
import Testing
@testable import DetoxDaemonKit

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Test func anchoredClockAdvancesWithMonotonic() {
    var c = TrustedClock()
    c.anchor(networkTime: t0, monotonic: 100)
    let r = c.now(monotonic: 160, wallClock: .distantPast)
    #expect(r.date == t0.addingTimeInterval(60) && r.isTrusted)
}

@Test func unanchoredUsesWallClockUntrusted() {
    let r = TrustedClock().now(monotonic: 5, wallClock: t0)
    #expect(r.date == t0 && !r.isTrusted)
}

@Test func wallClockJumpIgnoredOnceAnchored() {
    var c = TrustedClock()
    c.anchor(networkTime: t0, monotonic: 100)
    let r = c.now(monotonic: 110, wallClock: t0.addingTimeInterval(3 * 86400))
    #expect(r.date == t0.addingTimeInterval(10))
}

@Test func needsReanchorAfter1800s() {
    var c = TrustedClock()
    #expect(c.needsReanchor(monotonic: 0))
    c.anchor(networkTime: t0, monotonic: 100)
    #expect(!c.needsReanchor(monotonic: 1899))
    #expect(c.needsReanchor(monotonic: 1900))
}

@Test func monotonicClockMoves() {
    let a = MonotonicClock.now()
    #expect(a > 0 && MonotonicClock.now() >= a)
}

@Test func parsesHTTPDate() {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let expected = utc.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 13, minute: 28))!
    #expect(HTTPDate.parse("Sun, 15 Nov 2026 13:28:00 GMT") == expected)
    #expect(HTTPDate.parse("nonsense") == nil)
}

private func tmpStateURL() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("detox-\(UUID().uuidString)/state.json")
}

@Test func storeRoundTrip() throws {
    let store = StateStore(url: tmpStateURL())
    var s = DetoxState()
    _ = try s.registerFriend(name: "Ana", now: t0)
    try store.save(s)
    #expect(try store.load() == s)
}

@Test func storeMissingFileIsEmptyState() throws {
    #expect(try StateStore(url: tmpStateURL()).load() == DetoxState())
}

@Test func storeWritesMode0600() throws {
    let url = tmpStateURL()
    try StateStore(url: url).save(DetoxState())
    let fm = FileManager.default
    #expect((try fm.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int) == 0o600)
    #expect((try fm.attributesOfItem(atPath: url.deletingLastPathComponent().path)[.posixPermissions] as? Int) == 0o700)
}

@Test func storeMovesCorruptFileAside() throws {
    let url = tmpStateURL()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{not json".utf8).write(to: url)
    #expect(try StateStore(url: url).load() == DetoxState())
    let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    #expect(siblings.contains { $0.hasPrefix("state.json.corrupt-") })
}
