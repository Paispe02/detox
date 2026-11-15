import Combine
import DetoxCore
import Foundation

public enum LockKindChoice: Hashable {
    case noExit, password, friend(UUID)

    var strength: Int {
        switch self {
        case .password: return 1
        case .friend: return 2
        case .noExit: return 3
        }
    }
}

/// The editor mirrors the daemon's rules so loosening controls are disabled up front.
/// The daemon still decides; this only keeps the user from building a draft it will refuse.
@MainActor
public final class EditorModel: ObservableObject {
    public static let commitmentPhrase = "me comprometo"

    @Published public var draft: BlockDraft
    @Published public var lockChoice: LockKindChoice
    @Published public var password = ""
    @Published public var commitmentPhrase = ""
    @Published public var customDomainInput = ""

    public let existing: BlockView?
    private let friends: [FriendView]
    private let today: LocalDate

    public init(existing: BlockView?, friends: [FriendView], now: Date) {
        self.existing = existing
        self.friends = friends
        let tz = TimeZone.current
        today = LocalDate.containing(now, in: tz)
        if let e = existing {
            draft = BlockDraft(name: e.name, targets: e.targets, window: e.window, weekdays: e.weekdays,
                               startDate: e.startDate, endDate: e.endDate, timeZoneID: e.timeZoneID,
                               lock: .unchanged, pauseMinutes: e.pauseMinutes)
            switch e.lock {
            case .noExit: lockChoice = .noExit
            case .password: lockChoice = .password
            case .friend(let id, _): lockChoice = .friend(id)
            }
        } else {
            draft = BlockDraft(name: "Noches limpias", targets: BlockTargets(),
                               window: DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)),
                               weekdays: Set(Weekday.allCases), startDate: today, endDate: today.adding(days: 30),
                               timeZoneID: tz.identifier, lock: .password(""), pauseMinutes: 15)
            lockChoice = .password
        }
    }

    public var isRunning: Bool {
        guard let p = existing?.phase else { return false }
        return p == .running || p == .active || p == .paused
    }

    private var currentChoice: LockKindChoice? {
        switch existing?.lock {
        case .noExit?: return .noExit
        case .password?: return .password
        case .friend(let id, _)?: return .friend(id)
        case nil: return nil
        }
    }

    public var confirmedFriends: [FriendView] { friends.filter(\.isConfirmed) }

    public func canRemove(service: ServiceID) -> Bool {
        !(isRunning && existing!.targets.services.contains(service))
    }

    public func canRemove(domain: String) -> Bool {
        !(isRunning && existing!.targets.domains.contains(domain))
    }

    public func canRemove(app: AppTarget) -> Bool {
        !(isRunning && existing!.targets.apps.contains(app))
    }

    public var minimumEndDate: LocalDate {
        isRunning ? existing!.endDate : max(today, draft.startDate)
    }

    public var pauseRange: ClosedRange<Int> {
        isRunning ? 5...max(5, existing!.pauseMinutes) : pauseRange5to60
    }
    private let pauseRange5to60 = DetoxCore.pauseRange

    public var allowedLockKinds: [LockKindChoice] {
        let all: [LockKindChoice] = [.password] + confirmedFriends.map { .friend($0.id) } + [.noExit]
        guard isRunning, let current = currentChoice else { return all }
        return all.filter { choice in
            if choice == current { return true }
            if choice.strength == current.strength { return false }   // another friend or another password
            return choice.strength > current.strength
        }
    }

    public func toggle(service: ServiceID) {
        if draft.targets.services.contains(service) {
            if canRemove(service: service) { draft.targets.services.remove(service) }
        } else {
            draft.targets.services.insert(service)
        }
    }

    /// Returns an error message, or nil when the domain was added.
    public func addCustomDomain() -> String? {
        guard let d = DomainNormalizer.normalize(customDomainInput) else { return "Escribe un dominio como instagram.com" }
        draft.targets.domains.insert(d)
        customDomainInput = ""
        return nil
    }

    private var needsNewPassword: Bool {
        lockChoice == .password && currentChoice != .password
    }

    public var validationMessage: String? {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Ponle un nombre." }
        if draft.targets.isEmpty { return "Elige al menos una web, servicio o app." }
        if draft.weekdays.isEmpty { return "Elige al menos un día." }
        if draft.endDate < draft.startDate || draft.endDate < minimumEndDate { return "Revisa las fechas." }
        if needsNewPassword && password.count < 4 { return "La contraseña necesita al menos 4 caracteres." }
        if lockChoice == .noExit && currentChoice != .noExit
            && commitmentPhrase.trimmingCharacters(in: .whitespaces).lowercased() != Self.commitmentPhrase {
            return "Escribe «me comprometo» para confirmar que no tendrá salida."
        }
        return nil
    }

    public var canSubmit: Bool { validationMessage == nil }

    public func makeDraft() -> BlockDraft {
        var d = draft
        d.name = d.name.trimmingCharacters(in: .whitespaces)
        if lockChoice == currentChoice {
            d.lock = (lockChoice == .password && !password.isEmpty) ? .password(password) : .unchanged
        } else {
            switch lockChoice {
            case .noExit: d.lock = .noExit
            case .password: d.lock = .password(password)
            case .friend(let id): d.lock = .friend(id)
            }
        }
        return d
    }
}
