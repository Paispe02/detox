import Foundation

public struct LocalTime: Codable, Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(_ hour: Int, _ minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (a: LocalTime, b: LocalTime) -> Bool { a.minutesSinceMidnight < b.minutesSinceMidnight }
}

public enum Weekday: Int, Codable, CaseIterable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

func gregorian(_ tz: TimeZone) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    return cal
}

public struct LocalDate: Codable, Hashable, Comparable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(_ y: Int, _ m: Int, _ d: Int) {
        year = y
        month = m
        day = d
    }

    public static func < (a: LocalDate, b: LocalDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public static func containing(_ date: Date, in tz: TimeZone) -> LocalDate {
        let c = gregorian(tz).dateComponents([.year, .month, .day], from: date)
        return LocalDate(c.year!, c.month!, c.day!)
    }

    /// Noon UTC for this date — a stable anchor for calendar arithmetic.
    private var anchor: Date {
        gregorian(TimeZone(identifier: "UTC")!).date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    public func adding(days: Int) -> LocalDate {
        let utc = TimeZone(identifier: "UTC")!
        return .containing(gregorian(utc).date(byAdding: .day, value: days, to: anchor)!, in: utc)
    }

    public func weekday(in tz: TimeZone = TimeZone(identifier: "UTC")!) -> Weekday {
        Weekday(rawValue: gregorian(TimeZone(identifier: "UTC")!).component(.weekday, from: anchor))!
    }

    public func instant(at time: LocalTime, in tz: TimeZone) -> Date {
        gregorian(tz).date(from: DateComponents(year: year, month: month, day: day,
                                                hour: time.hour, minute: time.minute))!
    }

    /// Whole days from self to other.
    public func days(to other: LocalDate) -> Int {
        let utc = TimeZone(identifier: "UTC")!
        return gregorian(utc).dateComponents([.day], from: anchor, to: other.anchor).day!
    }
}

public struct DailyWindow: Codable, Hashable, Sendable {
    public var start: LocalTime
    public var end: LocalTime

    public init(start: LocalTime, end: LocalTime) {
        self.start = start
        self.end = end
    }

    public var crossesMidnight: Bool { end < start }
    public var isAllDay: Bool { start == end }
}
