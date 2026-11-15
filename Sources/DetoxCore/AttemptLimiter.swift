import Foundation

/// Global brake on unlock attempts: 5 consecutive failures → 10 minutes locked.
public struct AttemptLimiter: Codable, Equatable, Sendable {
    public static let maxFailures = 5
    public static let lockSeconds: TimeInterval = 600

    public var consecutiveFailures = 0
    public var lockedUntil: Date?

    public init() {}

    public func isLocked(at date: Date) -> Bool {
        if let until = lockedUntil { return date < until }
        return false
    }

    public mutating func recordFailure(at date: Date) {
        consecutiveFailures += 1
        if consecutiveFailures >= Self.maxFailures {
            lockedUntil = date.addingTimeInterval(Self.lockSeconds)
            consecutiveFailures = 0
        }
    }

    public mutating func recordSuccess() {
        consecutiveFailures = 0
    }
}
