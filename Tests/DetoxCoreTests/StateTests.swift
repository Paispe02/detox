import Foundation
import Testing
@testable import DetoxCore

private let night = madrid(2026, 12, 2, 23, 0)      // inside the 22:30–06:00 window
private let noon = madrid(2026, 12, 2, 12, 0)       // running, outside the window
private let before = madrid(2026, 11, 20, 12, 0)    // before start date

private func draft(_ lock: LockDraft = .password("1234"), services: Set<ServiceID> = [.youtube],
                   domains: Set<String> = []) -> BlockDraft {
    BlockDraft(name: "Noches limpias", targets: BlockTargets(services: services, domains: domains),
               window: DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)),
               weekdays: Set(Weekday.allCases), startDate: LocalDate(2026, 12, 1), endDate: LocalDate(2026, 12, 31),
               timeZoneID: "Europe/Madrid", lock: lock, pauseMinutes: 15)
}

private func expectError(_ expected: CommandError, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(expected)") } catch let e as CommandError { #expect(e == expected) }
    catch { Issue.record("unexpected \(error)") }
}

private func confirmedFriend(_ s: inout DetoxState, at t: Date) -> FriendKey {
    var f = FriendKey.generate(name: "Ana", now: t)
    f.isConfirmed = true
    s.friends.append(f)
    return f
}

@Test func createRejectsEmptyName() {
    var s = DetoxState(); var d = draft(); d.name = "   "
    expectError(.invalid("nombre")) { _ = try s.createBlock(d, now: before, isTrustedTime: true) }
}

@Test func createRejectsEmptyTargets() {
    var s = DetoxState()
    expectError(.invalid("objetivos")) { _ = try s.createBlock(draft(services: []), now: before, isTrustedTime: true) }
}

@Test func createRejectsNoWeekdays() {
    var s = DetoxState(); var d = draft(); d.weekdays = []
    expectError(.invalid("días")) { _ = try s.createBlock(d, now: before, isTrustedTime: true) }
}

@Test func createRejectsPastEndDate() {
    var s = DetoxState()
    expectError(.invalid("fechas")) { _ = try s.createBlock(draft(), now: madrid(2027, 1, 5, 12, 0), isTrustedTime: true) }
}

@Test func createRejectsPauseOutOfRange() {
    var s = DetoxState(); var d = draft(); d.pauseMinutes = 61
    expectError(.invalid("pausa")) { _ = try s.createBlock(d, now: before, isTrustedTime: true) }
}

@Test func createRejectsShortPassword() {
    var s = DetoxState()
    expectError(.invalid("contraseña")) { _ = try s.createBlock(draft(.password("12")), now: before, isTrustedTime: true) }
}

@Test func createRejectsUnchangedLock() {
    var s = DetoxState()
    expectError(.invalid("cerradura")) { _ = try s.createBlock(draft(.unchanged), now: before, isTrustedTime: true) }
}

@Test func createRejectsUnconfirmedFriend() {
    var s = DetoxState()
    let f = FriendKey.generate(name: "Ana", now: before)
    s.friends = [f]
    expectError(.friendNotConfirmed) { _ = try s.createBlock(draft(.friend(f.id)), now: before, isTrustedTime: true) }
    expectError(.unknownFriend) { _ = try s.createBlock(draft(.friend(UUID())), now: before, isTrustedTime: true) }
}

@Test func createNormalizesCustomDomains() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(domains: ["https://www.Twitch.tv/x"]), now: before, isTrustedTime: true)
    #expect(b.targets.domains == ["www.twitch.tv"])
    expectError(.invalid("dominio: no vale")) { _ = try s.createBlock(draft(domains: ["no vale"]), now: before, isTrustedTime: true) }
}

@Test func noExitIgnoresPauseRange() throws {
    var s = DetoxState(); var d = draft(.noExit); d.pauseMinutes = 0
    _ = try s.createBlock(d, now: before, isTrustedTime: true)
}

@Test func scheduledBlockCanBeFreelyEdited() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    var d = draft(.unchanged, services: [.instagram]); d.endDate = LocalDate(2026, 12, 10)
    let u = try s.updateBlock(id: b.id, with: d, now: before, isTrustedTime: true)
    #expect(u.targets.services == [.instagram] && u.endDate == LocalDate(2026, 12, 10) && u.lock == b.lock)
}

@Test func runningBlockRejectsLoosening() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(services: [.youtube, .instagram]), now: before, isTrustedTime: true)
    expectError(.tightening([.removesTargets])) {
        _ = try s.updateBlock(id: b.id, with: draft(.unchanged, services: [.youtube]), now: noon, isTrustedTime: true)
    }
}

@Test func runningBlockAcceptsTightening() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    let u = try s.updateBlock(id: b.id, with: draft(.noExit, services: [.youtube, .tiktok]), now: noon, isTrustedTime: true)
    #expect(u.lock == .noExit && u.id == b.id)
}

@Test func cannotDeleteRunningBlock() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    expectError(.notDeletable) { try s.deleteBlock(id: b.id, now: noon, isTrustedTime: true) }
}

@Test func canDeleteScheduledBlock() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    try s.deleteBlock(id: b.id, now: before, isTrustedTime: true)
    #expect(s.blocks.isEmpty)
}

@Test func noExitCannotBeUnlocked() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(.noExit), now: before, isTrustedTime: true)
    expectError(.noExit(endsAt: madrid(2027, 1, 1, 6, 0))) {
        _ = try s.unlock(blockID: b.id, credential: .password("x"), action: .pause, now: night, isTrustedTime: true)
    }
}

@Test func unlockOutsideWindowIsNotActive() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    expectError(.notActive) { _ = try s.unlock(blockID: b.id, credential: .password("1234"), action: .pause, now: noon, isTrustedTime: true) }
}

@Test func wrongPasswordCountsTowardLimit() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    for _ in 0..<5 {
        expectError(.wrongCredential) { _ = try s.unlock(blockID: b.id, credential: .password("0000"), action: .pause, now: night, isTrustedTime: true) }
    }
    expectError(.rateLimited(until: night.addingTimeInterval(600))) {
        _ = try s.unlock(blockID: b.id, credential: .password("1234"), action: .pause, now: night, isTrustedTime: true)
    }
}

@Test func passwordUnlockPausesForConfiguredMinutes() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    let u = try s.unlock(blockID: b.id, credential: .password("1234"), action: .pause, now: night, isTrustedTime: true)
    #expect(u.pausedUntil == night.addingTimeInterval(900))
    #expect(s.blocks[0].phase(at: night, isTrustedTime: true) == .paused)
}

@Test func passwordCannotCancel() throws {
    var s = DetoxState()
    let b = try s.createBlock(draft(), now: before, isTrustedTime: true)
    expectError(.cancelRequiresFriend) { _ = try s.unlock(blockID: b.id, credential: .password("1234"), action: .cancel, now: night, isTrustedTime: true) }
}

@Test func friendCodeCanCancel() throws {
    var s = DetoxState()
    let f = confirmedFriend(&s, at: before)
    let b = try s.createBlock(draft(.friend(f.id)), now: before, isTrustedTime: true)
    let code = TOTP.code(secret: f.secret, counter: TOTP.counter(at: night))
    let u = try s.unlock(blockID: b.id, credential: .friendCode(code), action: .cancel, now: night, isTrustedTime: true)
    #expect(u.cancelledAt == night)
}

@Test func friendCodeIsSingleUse() throws {
    var s = DetoxState()
    let f = confirmedFriend(&s, at: before)
    let b = try s.createBlock(draft(.friend(f.id)), now: before, isTrustedTime: true)
    let code = TOTP.code(secret: f.secret, counter: TOTP.counter(at: night))
    _ = try s.unlock(blockID: b.id, credential: .friendCode(code), action: .pause, now: night, isTrustedTime: true)
    s.blocks[0].pausedUntil = nil
    expectError(.wrongCredential) { _ = try s.unlock(blockID: b.id, credential: .friendCode(code), action: .pause, now: night, isTrustedTime: true) }
}

@Test func passwordCredentialOnFriendLockIsWrong() throws {
    var s = DetoxState()
    let f = confirmedFriend(&s, at: before)
    let b = try s.createBlock(draft(.friend(f.id)), now: before, isTrustedTime: true)
    expectError(.wrongCredential) { _ = try s.unlock(blockID: b.id, credential: .password("1234"), action: .pause, now: night, isTrustedTime: true) }
}

@Test func registerAndConfirmFriend() throws {
    var s = DetoxState()
    let f = try s.registerFriend(name: "Ana", now: night)
    #expect(!s.friends[0].isConfirmed)
    expectError(.wrongCredential) { try s.confirmFriend(id: f.id, code: "000000", now: night) }
    try s.confirmFriend(id: f.id, code: TOTP.code(secret: f.secret, counter: TOTP.counter(at: night)), now: night)
    #expect(s.friends[0].isConfirmed)
    expectError(.invalid("nombre")) { _ = try s.registerFriend(name: " ", now: night) }
}

@Test func cannotDeleteFriendInUse() throws {
    var s = DetoxState()
    let f = confirmedFriend(&s, at: before)
    _ = try s.createBlock(draft(.friend(f.id)), now: before, isTrustedTime: true)
    expectError(.friendInUse) { try s.deleteFriend(id: f.id, now: before, isTrustedTime: true) }
    try s.deleteFriend(id: f.id, now: madrid(2027, 2, 1, 12, 0), isTrustedTime: true)   // block finished
    #expect(s.friends.isEmpty)
}

@Test func snapshotNeverContainsSecrets() throws {
    var s = DetoxState()
    let f = confirmedFriend(&s, at: before)
    _ = try s.createBlock(draft(), now: before, isTrustedTime: true)
    let json = String(decoding: try JSONEncoder().encode(s.snapshot(now: night, isTrustedTime: true)), as: UTF8.self)
    #expect(!json.contains(f.secret.base64EncodedString()))
    #expect(!json.contains(Base32.encode(f.secret)))
    if case .password(let h) = s.blocks[0].lock { #expect(!json.contains(h.hash.base64EncodedString())) }
}

@Test func snapshotDescribesActiveBlock() throws {
    var s = DetoxState()
    let f = confirmedFriend(&s, at: before)
    _ = try s.createBlock(draft(.friend(f.id)), now: before, isTrustedTime: true)
    let snap = s.snapshot(now: night, isTrustedTime: true)
    let v = snap.blocks[0]
    #expect(v.phase == .active && v.lock == .friend(id: f.id, name: "Ana"))
    #expect(v.activeWindowEnd == madrid(2026, 12, 3, 6, 0))
    #expect(v.progressCurrent == 2 && v.progressTotal == 31)
    #expect(snap.blockedDomainsNow.contains("www.youtube.com"))
    #expect(snap.friends[0].blockNames == ["Noches limpias"])
}
