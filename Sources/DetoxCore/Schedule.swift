import Foundation

extension Block {
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// The window that starts on `day` (local to the block's time zone).
    public func windowInterval(startingOn day: LocalDate) -> DateInterval {
        let start = day.instant(at: window.start, in: timeZone)
        let end: Date
        if window.isAllDay {
            end = day.adding(days: 1).instant(at: window.start, in: timeZone)
        } else if window.crossesMidnight {
            end = day.adding(days: 1).instant(at: window.end, in: timeZone)
        } else {
            end = day.instant(at: window.end, in: timeZone)
        }
        return DateInterval(start: start, end: end)
    }

    public var commitmentInterval: DateInterval {
        let start = startDate.instant(at: LocalTime(0, 0), in: timeZone)
        let endTime = window.crossesMidnight ? window.end : LocalTime(0, 0)
        return DateInterval(start: start, end: endDate.adding(days: 1).instant(at: endTime, in: timeZone))
    }

    private func isWindowDay(_ d: LocalDate) -> Bool {
        d >= startDate && d <= endDate && weekdays.contains(d.weekday())
    }

    public func activeWindow(at now: Date) -> DateInterval? {
        let today = LocalDate.containing(now, in: timeZone)
        for d in [today, today.adding(days: -1)] where isWindowDay(d) {
            let w = windowInterval(startingOn: d)
            if now >= w.start && now < w.end { return w }
        }
        return nil
    }

    public func nextWindowStart(after now: Date) -> Date? {
        var d = max(LocalDate.containing(now, in: timeZone).adding(days: -1), startDate)
        while d <= endDate {
            if isWindowDay(d) {
                let s = windowInterval(startingOn: d).start
                if s > now { return s }
            }
            d = d.adding(days: 1)
        }
        return nil
    }

    public func phase(at now: Date, isTrustedTime: Bool) -> BlockPhase {
        if cancelledAt != nil { return .finished }
        let c = commitmentInterval
        if now < c.start { return .scheduled }
        if now >= c.end && isTrustedTime { return .finished }
        if activeWindow(at: now) != nil {
            if let p = pausedUntil, p > now { return .paused }
            return .active
        }
        return .running
    }

    public func progress(at now: Date) -> (current: Int, total: Int) {
        var total = 0
        var current = 0
        var d = startDate
        while d <= endDate {
            if isWindowDay(d) {
                total += 1
                if windowInterval(startingOn: d).start <= now { current += 1 }
            }
            d = d.adding(days: 1)
        }
        return (current, total)
    }
}
