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

public enum InterceptTiming {
    public static let minimumSeconds: TimeInterval = 60
    public static let cooldownSeconds: TimeInterval = 20

    public static func canClose(elapsed: TimeInterval, videoEnded: Bool) -> Bool {
        videoEnded || elapsed >= minimumSeconds
    }
}
