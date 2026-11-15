import Foundation
import Testing
@testable import DetoxCore

private let before = madrid(2026, 11, 20, 12, 0)
private let noon = madrid(2026, 12, 2, 12, 0)
private let night = madrid(2026, 12, 2, 23, 0)

private func appBundle(id: String, under dir: URL) throws -> String {
    let app = dir.appendingPathComponent("Juego.app")
    try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id], format: .xml, options: 0)
        .write(to: app.appendingPathComponent("Contents/Info.plist"))
    return app.path
}

private func draft(apps: Set<AppTarget> = [], services: Set<ServiceID> = [], lock: LockDraft = .password("1234")) -> BlockDraft {
    BlockDraft(name: "Apps", targets: BlockTargets(services: services, apps: apps),
               window: DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)), weekdays: Set(Weekday.allCases),
               startDate: LocalDate(2026, 12, 1), endDate: LocalDate(2026, 12, 31), timeZoneID: "Europe/Madrid",
               lock: lock, pauseMinutes: 15)
}

private func rejects(_ app: AppTarget) {
    var s = DetoxState()
    do { _ = try s.createBlock(draft(apps: [app]), now: before, isTrustedTime: true); Issue.record("accepted \(app.path)") }
    catch let e as CommandError { #expect(e == .invalid("app: \(app.name)")) } catch { Issue.record("\(error)") }
}

@Test func rejectsEmptyAppPath() { rejects(AppTarget(bundleID: "x", name: "Todo", path: "")) }
@Test func rejectsSystemPaths() {
    rejects(AppTarget(bundleID: "com.apple.loginwindow", name: "loginwindow", path: "/System/Library/CoreServices/loginwindow.app"))
    rejects(AppTarget(bundleID: "x", name: "sbin", path: "/sbin"))
}
@Test func rejectsCriticalBundleIDs() {
    rejects(AppTarget(bundleID: "com.apple.finder", name: "Finder", path: "/System/Library/CoreServices/Finder.app"))
}
@Test func rejectsBundleIDMismatch() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let path = try appBundle(id: "com.game.real", under: dir)
    rejects(AppTarget(bundleID: "com.other", name: "Juego", path: path))
}
@Test func acceptsRealAppBundle() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let path = try appBundle(id: "com.game.real", under: dir)
    var s = DetoxState()
    _ = try s.createBlock(draft(apps: [AppTarget(bundleID: "com.game.real", name: "Juego", path: path)]), now: before, isTrustedTime: true)
}

@Test func runningBlockCannotSwitchToFriendRegisteredDuringIt() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(services: [.youtube]), now: before, isTrustedTime: true)
    let f = try s.registerFriend(name: "Bot", now: noon)
    try s.confirmFriend(id: f.id, code: TOTP.code(secret: f.secret, counter: TOTP.counter(at: noon)), now: noon)
    do { _ = try s.updateBlock(id: b.id, with: draft(services: [.youtube], lock: .friend(f.id)), now: noon, isTrustedTime: true); Issue.record("accepted") }
    catch let e as CommandError { #expect(e == .invalid("amigo reciente")) }
}

@Test func runningBlockCanSwitchToFriendRegisteredBeforeIt() throws {
    var s = DetoxState()
    let f = try s.registerFriend(name: "Ana", now: before)
    try s.confirmFriend(id: f.id, code: TOTP.code(secret: f.secret, counter: TOTP.counter(at: before)), now: before)
    let b = try s.createBlock(draft(services: [.youtube]), now: before, isTrustedTime: true)
    _ = try s.updateBlock(id: b.id, with: draft(services: [.youtube], lock: .friend(f.id)), now: noon, isTrustedTime: true)
}

@Test func untrustedClockNeverGoesBehindLastTrustedTime() {
    var s = DetoxState()
    s.lastTrustedTime = night
    #expect(s.effectiveNow(wall: before, isTrusted: false) == night)
    #expect(s.effectiveNow(wall: night + 60, isTrusted: false) == night + 60)
    #expect(s.effectiveNow(wall: before, isTrusted: true) == before)
}

@Test func oldStateWithoutLastTrustedTimeDecodes() throws {
    let json = #"{"version":1,"blocks":[],"friends":[],"limiter":{"consecutiveFailures":0}}"#
    let s = try JSONDecoder().decode(DetoxState.self, from: Data(json.utf8))
    #expect(s.lastTrustedTime == nil)
}
