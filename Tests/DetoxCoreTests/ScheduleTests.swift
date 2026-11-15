import Foundation
import Testing
@testable import DetoxCore

@Test func overnightWindowActiveAfterMidnight() {
    #expect(Block.fixture().activeWindow(at: madrid(2026, 12, 2, 1, 0))
            == DateInterval(start: madrid(2026, 12, 1, 22, 30), end: madrid(2026, 12, 2, 6, 0)))
}

@Test func overnightWindowInactiveAtNoon() {
    let b = Block.fixture()
    #expect(b.activeWindow(at: madrid(2026, 12, 2, 12, 0)) == nil)
    #expect(b.phase(at: madrid(2026, 12, 2, 12, 0), isTrustedTime: true) == .running)
}

@Test func weekdaysRefersToStartDay() {
    let b = Block.fixture(weekdays: [.monday])
    #expect(b.activeWindow(at: madrid(2026, 12, 8, 2, 0)) != nil)
    #expect(b.activeWindow(at: madrid(2026, 12, 7, 2, 0)) == nil)
}

@Test func lastWindowEndsNextMorning() {
    let b = Block.fixture()
    #expect(b.activeWindow(at: madrid(2027, 1, 1, 5, 59)) != nil)
    #expect(b.activeWindow(at: madrid(2027, 1, 1, 6, 0)) == nil)
    #expect(b.phase(at: madrid(2027, 1, 1, 6, 0), isTrustedTime: true) == .finished)
}

@Test func dayBeforeStartIsNotBlocked() {
    let b = Block.fixture()
    #expect(b.phase(at: madrid(2026, 11, 30, 23, 0), isTrustedTime: true) == .scheduled)
    #expect(b.activeWindow(at: madrid(2026, 12, 1, 0, 30)) == nil)
}

@Test func untrustedTimeNeverFinishes() {
    let b = Block.fixture()
    #expect(b.phase(at: madrid(2027, 2, 1, 12, 0), isTrustedTime: false) == .running)
    #expect(b.phase(at: madrid(2027, 2, 1, 12, 0), isTrustedTime: true) == .finished)
}

@Test func springForwardWindowIsThreeHours() {
    let b = Block.fixture(window: DailyWindow(start: LocalTime(1, 0), end: LocalTime(5, 0)),
                          startDate: LocalDate(2027, 3, 27), endDate: LocalDate(2027, 3, 28))
    let w = b.windowInterval(startingOn: LocalDate(2027, 3, 28))
    #expect(w.duration == 3 * 3600)
    #expect(b.activeWindow(at: madrid(2027, 3, 28, 4, 30)) == w)
}

@Test func allDayWindow() {
    let b = Block.fixture(window: DailyWindow(start: LocalTime(0, 0), end: LocalTime(0, 0)))
    #expect(b.windowInterval(startingOn: LocalDate(2026, 12, 5)).duration == 24 * 3600)
    #expect(b.activeWindow(at: madrid(2026, 12, 5, 15, 0)) != nil)
}

@Test func evaluatesInBlockTimeZoneNotProcessTimeZone() {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let instant = utc.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 22))!
    #expect(Block.fixture().activeWindow(at: instant) != nil)
}

@Test func progressCountsNights() {
    let p = Block.fixture().progress(at: madrid(2026, 12, 5, 23, 0))
    #expect(p.current == 5 && p.total == 31)
}

@Test func nextWindowStartIsTonight() {
    #expect(Block.fixture().nextWindowStart(after: madrid(2026, 12, 5, 12, 0)) == madrid(2026, 12, 5, 22, 30))
}

@Test func cancelledIsFinished() {
    var b = Block.fixture()
    b.cancelledAt = madrid(2026, 12, 3, 23, 0)
    #expect(b.phase(at: madrid(2026, 12, 4, 23, 0), isTrustedTime: true) == .finished)
}

@Test func pausedThenActiveAgain() {
    var b = Block.fixture()
    b.pausedUntil = madrid(2026, 12, 2, 23, 15)
    #expect(b.phase(at: madrid(2026, 12, 2, 23, 0), isTrustedTime: true) == .paused)
    #expect(b.phase(at: madrid(2026, 12, 2, 23, 15), isTrustedTime: true) == .active)
}
