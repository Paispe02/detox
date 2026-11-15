import DetoxIPC
import Foundation

/// Decides whether an attempt is the user reaching for the site, or background noise.
public enum AttemptPolicy {
    public static func shouldShowScreen(event: AttemptEvent, frontmostBundleID: String?, frontTabHost: String?,
                                        automationAvailable: Bool, blockedDomains: Set<String>) -> Bool {
        switch event.target {
        case .app:
            return true
        case .domain:
            guard let front = frontmostBundleID, Browser(rawValue: front) != nil else { return false }
            if automationAvailable {
                guard let host = frontTabHost else { return false }
                return BrowserTabs.matches(host: host, domains: blockedDomains)
            }
            return event.isPrimaryDomain
        }
    }
}

/// The same thing (a tab's URL, an app) shows the screen at most once every 5 minutes:
/// an open page retries its connections on its own, and that is not the user reaching for it.
public struct RepeatGuard {
    public static let interval: TimeInterval = 300
    private var lastShown: [String: Date] = [:]

    public init() {}

    public mutating func allow(_ key: String, at now: Date) -> Bool {
        if let last = lastShown[key], now.timeIntervalSince(last) < Self.interval { return false }
        lastShown[key] = now
        return true
    }
}

/// Remembers which blocked tabs were already reloaded, so each is silenced once per block period.
public struct TabSilencer {
    private var done: Set<String> = []
    private var lastBlocked: Set<String> = []

    public init() {}

    public mutating func pending(_ tabs: [TabRef], blocked: Set<String>) -> [TabRef] {
        if blocked != lastBlocked { done = []; lastBlocked = blocked }
        guard !blocked.isEmpty else { return [] }
        let fresh = tabs.filter { tab in
            guard let host = BrowserTabs.host(of: tab.url), BrowserTabs.matches(host: host, domains: blocked) else { return false }
            return !done.contains("\(tab.browser.rawValue)|\(tab.url)")
        }
        fresh.forEach { done.insert("\($0.browser.rawValue)|\($0.url)") }
        return fresh
    }
}

public enum InterceptTiming {
    public static let minimumSeconds: TimeInterval = 60
    public static let cooldownSeconds: TimeInterval = 20

    public static func canClose(elapsed: TimeInterval, videoEnded: Bool) -> Bool {
        videoEnded || elapsed >= minimumSeconds
    }
}
