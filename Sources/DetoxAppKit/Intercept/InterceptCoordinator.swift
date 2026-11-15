import DetoxCore
import Foundation

public enum InterceptContent: Equatable {
    case video(URL, blockName: String)
    case fallback(phrase: String, blockName: String, opensAt: Date?, progress: (current: Int, total: Int)?, window: DailyWindow? = nil)

    public static func == (a: InterceptContent, b: InterceptContent) -> Bool {
        switch (a, b) {
        case let (.video(u1, n1), .video(u2, n2)): return u1 == u2 && n1 == n2
        case let (.fallback(p1, n1, o1, g1, w1), .fallback(p2, n2, o2, g2, w2)):
            return p1 == p2 && n1 == n2 && o1 == o2 && g1?.current == g2?.current && g1?.total == g2?.total && w1 == w2
        default: return false
        }
    }

    public var blockName: String {
        switch self {
        case .video(_, let n): return n
        case .fallback(_, let n, _, _, _): return n
        }
    }
}

@MainActor
public protocol InterceptPresenting: AnyObject {
    func present(_ content: InterceptContent, onDismiss: @escaping () -> Void)
}

/// One screen at a time; after it closes, 20 s in which new attempts are ignored (browsers retry on their own).
@MainActor
public final class InterceptCoordinator {
    private let presenter: InterceptPresenting
    private let now: () -> Date
    private var cooldownUntil = Date.distantPast
    public private(set) var isShowing = false

    public init(presenter: InterceptPresenting, now: @escaping () -> Date = Date.init) {
        self.presenter = presenter
        self.now = now
    }

    public func handle(_ content: InterceptContent) {
        guard !isShowing, now() >= cooldownUntil else { return }
        isShowing = true
        presenter.present(content) { [weak self] in
            guard let self else { return }
            self.isShowing = false
            self.cooldownUntil = self.now().addingTimeInterval(InterceptTiming.cooldownSeconds)
        }
    }
}
