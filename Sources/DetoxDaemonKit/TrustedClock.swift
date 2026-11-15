import Darwin
import Foundation

public enum MonotonicClock {
    /// Seconds on a clock that keeps counting while the Mac sleeps and ignores wall-clock changes.
    public static func now() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9
    }
}

/// Network time anchored to the monotonic clock, so changing the Mac's clock can't end a commitment.
public struct TrustedClock: Sendable {
    public static let reanchorInterval: TimeInterval = 1800

    private var anchorTime: Date?
    private var anchorMonotonic: TimeInterval = 0

    public init() {}

    public mutating func anchor(networkTime: Date, monotonic: TimeInterval) {
        anchorTime = networkTime
        anchorMonotonic = monotonic
    }

    public func now(monotonic: TimeInterval, wallClock: Date) -> (date: Date, isTrusted: Bool) {
        guard let t = anchorTime else { return (wallClock, false) }
        return (t.addingTimeInterval(monotonic - anchorMonotonic), true)
    }

    public func needsReanchor(monotonic: TimeInterval) -> Bool {
        anchorTime == nil || monotonic - anchorMonotonic >= Self.reanchorInterval
    }
}
