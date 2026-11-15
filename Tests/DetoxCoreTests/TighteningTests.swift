import Foundation
import Testing
@testable import DetoxCore

private func base(_ lock: Lock = .password(.dummy)) -> Block {
    Block.fixture(targets: BlockTargets(services: [.youtube], domains: ["reddit.com"]),
                  weekdays: [.monday], lock: lock, pauseMinutes: 15)
}

@Test func allowedTightening() {
    let old = base()
    var new = old
    new.targets.services.insert(.instagram)
    new.endDate = LocalDate(2027, 1, 31)
    new.window = DailyWindow(start: LocalTime(22, 0), end: LocalTime(7, 0))
    new.weekdays = [.monday, .tuesday]
    new.lock = .noExit
    new.pauseMinutes = 10
    new.name = "Otro nombre"
    #expect(tighteningViolations(from: old, to: new).isEmpty)
}

@Test func removingTargetIsRejected() {
    var new = base(); new.targets.domains = []
    #expect(tighteningViolations(from: base(), to: new) == [.removesTargets])
}

@Test func shorteningEndDateIsRejected() {
    var new = base(); new.endDate = LocalDate(2026, 12, 20)
    #expect(tighteningViolations(from: base(), to: new) == [.shortensEndDate])
}

@Test func changingStartDateIsRejected() {
    var new = base(); new.startDate = LocalDate(2026, 11, 20)
    #expect(tighteningViolations(from: base(), to: new) == [.changesStartDate])
}

@Test func movingWindowLaterIsShrink() {
    var new = base(); new.window = DailyWindow(start: LocalTime(23, 0), end: LocalTime(7, 0))
    #expect(tighteningViolations(from: base(), to: new) == [.shrinksSchedule])
}

@Test func removingWeekdayIsShrink() {
    let old = Block.fixture(weekdays: [.monday, .tuesday])
    var new = old; new.weekdays = [.monday]
    #expect(tighteningViolations(from: old, to: new) == [.shrinksSchedule])
}

@Test func passwordToFriendIsAllowed() {
    var new = base(); new.lock = .friend(UUID())
    #expect(tighteningViolations(from: base(), to: new).isEmpty)
}

@Test func friendToPasswordWeakens() {
    let old = base(.friend(UUID()))
    var new = old; new.lock = .password(.dummy)
    #expect(tighteningViolations(from: old, to: new) == [.weakensLock])
}

@Test func noExitToAnythingWeakens() {
    let old = base(.noExit)
    var new = old; new.lock = .friend(UUID())
    #expect(tighteningViolations(from: old, to: new) == [.weakensLock])
}

@Test func changingPasswordIsSecretChange() {
    var other = PasswordHash.dummy; other.hash = Data(repeating: 9, count: 32)
    var new = base(); new.lock = .password(other)
    #expect(tighteningViolations(from: base(), to: new) == [.changesLockSecret])
}

@Test func changingFriendIsSecretChange() {
    let old = base(.friend(UUID()))
    var new = old; new.lock = .friend(UUID())
    #expect(tighteningViolations(from: old, to: new) == [.changesLockSecret])
}

@Test func lengtheningPauseIsRejected() {
    var new = base(); new.pauseMinutes = 30
    #expect(tighteningViolations(from: base(), to: new) == [.lengthensPause])
}

@Test func changingTimeZoneIsRejected() {
    var new = base(); new.timeZoneID = "America/New_York"
    #expect(tighteningViolations(from: base(), to: new) == [.changesTimeZone])
}

@Test func saturdayNightWrapsIntoSunday() {
    let m = coveredMinutesOfWeek(window: DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)), weekdays: [.saturday])
    #expect(m.contains(0) && m.contains(359) && !m.contains(360))
    #expect(m.contains(6 * 1440 + 22 * 60 + 30))
}
