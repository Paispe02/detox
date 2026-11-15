import Foundation

public enum LockSummary: Codable, Hashable, Sendable {
    case noExit
    case password
    case friend(id: UUID, name: String)
}

/// What the app may see of a block: no password hashes, no friend secrets.
public struct BlockView: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var targets: BlockTargets
    public var window: DailyWindow
    public var weekdays: Set<Weekday>
    public var startDate: LocalDate
    public var endDate: LocalDate
    public var timeZoneID: String
    public var lock: LockSummary
    public var pauseMinutes: Int
    public var phase: BlockPhase
    public var pausedUntil: Date?
    public var activeWindowEnd: Date?
    public var nextWindowStart: Date?
    public var commitmentEnd: Date
    public var progressCurrent: Int
    public var progressTotal: Int
}

public struct FriendView: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isConfirmed: Bool
    public var blockNames: [String]
}

public struct StatusSnapshot: Codable, Equatable, Sendable {
    public var now: Date
    public var isTrustedTime: Bool
    public var blocks: [BlockView]
    public var friends: [FriendView]
    public var blockedDomainsNow: [String]
    public var rateLimitedUntil: Date?

    public init(now: Date, isTrustedTime: Bool, blocks: [BlockView], friends: [FriendView],
                blockedDomainsNow: [String], rateLimitedUntil: Date?) {
        self.now = now
        self.isTrustedTime = isTrustedTime
        self.blocks = blocks
        self.friends = friends
        self.blockedDomainsNow = blockedDomainsNow
        self.rateLimitedUntil = rateLimitedUntil
    }
}

extension DetoxState {
    public func view(of b: Block, now: Date, isTrustedTime: Bool) -> BlockView {
        let lock: LockSummary
        switch b.lock {
        case .noExit: lock = .noExit
        case .password: lock = .password
        case .friend(let id): lock = .friend(id: id, name: friends.first { $0.id == id }?.name ?? "?")
        }
        let p = b.progress(at: now)
        let phase = b.phase(at: now, isTrustedTime: isTrustedTime)
        return BlockView(id: b.id, name: b.name, targets: b.targets, window: b.window, weekdays: b.weekdays,
                         startDate: b.startDate, endDate: b.endDate, timeZoneID: b.timeZoneID, lock: lock,
                         pauseMinutes: b.pauseMinutes, phase: phase,
                         pausedUntil: phase == .paused ? b.pausedUntil : nil,
                         activeWindowEnd: b.activeWindow(at: now)?.end,
                         nextWindowStart: phase == .finished ? nil : b.nextWindowStart(after: now),
                         commitmentEnd: b.commitmentInterval.end,
                         progressCurrent: p.current, progressTotal: p.total)
    }

    public func snapshot(now: Date, isTrustedTime: Bool) -> StatusSnapshot {
        let plan = makeEnforcementPlan(blocks: blocks, now: now, isTrustedTime: isTrustedTime)
        let friendViews = friends.map { f in
            FriendView(id: f.id, name: f.name, isConfirmed: f.isConfirmed,
                       blockNames: blocks.filter { $0.lock == .friend(f.id) }.map(\.name))
        }
        return StatusSnapshot(now: now, isTrustedTime: isTrustedTime,
                              blocks: blocks.map { view(of: $0, now: now, isTrustedTime: isTrustedTime) },
                              friends: friendViews,
                              blockedDomainsNow: plan.blockedDomains.keys.sorted(),
                              rateLimitedUntil: limiter.isLocked(at: now) ? limiter.lockedUntil : nil)
    }
}
