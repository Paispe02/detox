import Foundation

public enum ServiceID: String, Codable, CaseIterable, Sendable {
    case instagram, youtube, tiktok, x, facebook, reddit, whatsapp
}

public struct AppTarget: Codable, Hashable, Sendable {
    public var bundleID: String
    public var name: String
    public var path: String

    public init(bundleID: String, name: String, path: String) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
    }
}

public struct BlockTargets: Codable, Hashable, Sendable {
    public var services: Set<ServiceID>
    public var domains: Set<String>
    public var apps: Set<AppTarget>

    public init(services: Set<ServiceID> = [], domains: Set<String> = [], apps: Set<AppTarget> = []) {
        self.services = services
        self.domains = domains
        self.apps = apps
    }

    public var isEmpty: Bool { services.isEmpty && domains.isEmpty && apps.isEmpty }
}

public struct PasswordHash: Codable, Hashable, Sendable {
    public var salt: Data
    public var iterations: Int
    public var hash: Data

    public init(salt: Data, iterations: Int, hash: Data) {
        self.salt = salt
        self.iterations = iterations
        self.hash = hash
    }
}

public enum Lock: Codable, Hashable, Sendable {
    case noExit
    case password(PasswordHash)
    case friend(UUID)

    public var strength: Int {
        switch self {
        case .password: return 1
        case .friend: return 2
        case .noExit: return 3
        }
    }
}

public enum BlockPhase: String, Codable, Sendable {
    case scheduled, running, active, paused, finished
}

public struct Block: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var targets: BlockTargets
    public var window: DailyWindow
    public var weekdays: Set<Weekday>
    public var startDate: LocalDate
    public var endDate: LocalDate
    public var timeZoneID: String
    public var lock: Lock
    public var pauseMinutes: Int
    public var pausedUntil: Date?
    public var cancelledAt: Date?

    public init(id: UUID, name: String, targets: BlockTargets, window: DailyWindow, weekdays: Set<Weekday>,
                startDate: LocalDate, endDate: LocalDate, timeZoneID: String, lock: Lock,
                pauseMinutes: Int, pausedUntil: Date?, cancelledAt: Date?) {
        self.id = id
        self.name = name
        self.targets = targets
        self.window = window
        self.weekdays = weekdays
        self.startDate = startDate
        self.endDate = endDate
        self.timeZoneID = timeZoneID
        self.lock = lock
        self.pauseMinutes = pauseMinutes
        self.pausedUntil = pausedUntil
        self.cancelledAt = cancelledAt
    }
}
