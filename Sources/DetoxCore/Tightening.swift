import Foundation

public enum TighteningViolation: String, Codable, Error, Sendable {
    case removesTargets, shortensEndDate, changesStartDate, shrinksSchedule
    case weakensLock, changesLockSecret, lengthensPause, changesTimeZone
}

private let minutesPerWeek = 7 * 1440

/// Minute-of-week indices (Sunday 00:00 = 0) covered by the window on the given start days.
public func coveredMinutesOfWeek(window: DailyWindow, weekdays: Set<Weekday>) -> Set<Int> {
    let start = window.start.minutesSinceMidnight
    let length: Int
    if window.isAllDay { length = 1440 }
    else if window.crossesMidnight { length = 1440 - start + window.end.minutesSinceMidnight }
    else { length = window.end.minutesSinceMidnight - start }
    var result = Set<Int>()
    for day in weekdays {
        let dayStart = (day.rawValue - 1) * 1440 + start
        for m in 0..<length { result.insert((dayStart + m) % minutesPerWeek) }
    }
    return result
}

/// Empty when `new` is at least as strict as `old` in every dimension.
public func tighteningViolations(from old: Block, to new: Block) -> [TighteningViolation] {
    var v: [TighteningViolation] = []
    if !(new.targets.services.isSuperset(of: old.targets.services)
         && new.targets.domains.isSuperset(of: old.targets.domains)
         && new.targets.apps.isSuperset(of: old.targets.apps)) { v.append(.removesTargets) }
    if new.endDate < old.endDate { v.append(.shortensEndDate) }
    if new.startDate != old.startDate { v.append(.changesStartDate) }
    if !coveredMinutesOfWeek(window: new.window, weekdays: new.weekdays)
        .isSuperset(of: coveredMinutesOfWeek(window: old.window, weekdays: old.weekdays)) { v.append(.shrinksSchedule) }
    if new.lock.strength < old.lock.strength {
        v.append(.weakensLock)
    } else if new.lock.strength == old.lock.strength && new.lock != old.lock {
        v.append(.changesLockSecret)
    }
    if new.lock != .noExit && new.pauseMinutes > old.pauseMinutes { v.append(.lengthensPause) }
    if new.timeZoneID != old.timeZoneID { v.append(.changesTimeZone) }
    return v
}
