import AppKit
import CoreServices
import Foundation

public enum Browser: String, CaseIterable, Sendable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"

    var activeTabTerm: String { self == .safari ? "current tab" : "active tab" }
}

public protocol AppleScriptRunning {
    func run(_ source: String) throws -> NSAppleEventDescriptor
}

public struct AppleScriptError: Error { public let info: [String: Any] }

public final class NSAppleScriptRunner: AppleScriptRunning {
    public init() {}

    public func run(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw AppleScriptError(info: [:]) }
        let result = script.executeAndReturnError(&error)
        if let error { throw AppleScriptError(info: error as? [String: Any] ?? [:]) }
        return result
    }
}

public struct TabRef: Equatable {
    public var browser: Browser
    public var window: Int
    public var tab: Int
    public var url: String
}

/// Reads and closes browser tabs over Apple Events. Never talks to a browser that is not running,
/// because `tell application` would launch it.
public final class BrowserTabs {
    private let scripts: AppleScriptRunning
    private let isRunning: (Browser) -> Bool
    private let frontmostBundleID: () -> String?

    public init(scripts: AppleScriptRunning = NSAppleScriptRunner(),
                isRunning: @escaping (Browser) -> Bool = BrowserTabs.systemIsRunning,
                frontmostBundleID: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }) {
        self.scripts = scripts
        self.isRunning = isRunning
        self.frontmostBundleID = frontmostBundleID
    }

    public static func systemIsRunning(_ b: Browser) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: b.rawValue).isEmpty
    }

    private func tell(_ b: Browser, _ body: String) -> String {
        "tell application id \"\(b.rawValue)\" to \(body)"
    }

    public func frontTabURL() -> String? {
        guard let id = frontmostBundleID(), let b = Browser(rawValue: id), isRunning(b) else { return nil }
        return try? scripts.run(tell(b, "get URL of \(b.activeTabTerm) of front window")).stringValue
    }

    public func frontTabHost() -> String? {
        frontTabURL().flatMap(Self.host(of:))
    }

    public func blockedTabs(matching domains: Set<String>) -> [TabRef] {
        guard !domains.isEmpty else { return [] }
        return listTabs().filter { Self.host(of: $0.url).map { Self.matches(host: $0, domains: domains) } ?? false }
    }

    /// Reloads the tabs in place: the page can't load while blocked, so a playing video stops,
    /// but the tab and its window stay, and the user can reload it once the block is over.
    @discardableResult
    public func reloadTabs(_ refs: [TabRef]) -> Int {
        for ref in refs where isRunning(ref.browser) {
            let target = "tab \(ref.tab) of window \(ref.window)"
            let body = ref.browser == .chrome ? "reload \(target)" : "set URL of \(target) to URL of \(target)"
            _ = try? scripts.run(tell(ref.browser, body))
        }
        return refs.count
    }

    public func listTabs() -> [TabRef] {
        Browser.allCases.filter(isRunning).flatMap { b -> [TabRef] in
            guard let list = try? scripts.run(tell(b, "get URL of every tab of every window")) else { return [] }
            var out: [TabRef] = []
            for w in stride(from: 1, through: list.numberOfItems, by: 1) {
                guard let window = list.atIndex(w) else { continue }
                for t in stride(from: 1, through: window.numberOfItems, by: 1) {
                    if let url = window.atIndex(t)?.stringValue { out.append(TabRef(browser: b, window: w, tab: t, url: url)) }
                }
            }
            return out
        }
    }

    /// Closes every tab whose host is (a subdomain of) a blocked domain. Returns how many.
    @discardableResult
    public func closeTabs(matching domains: Set<String>) -> Int {
        guard !domains.isEmpty else { return 0 }
        let doomed = listTabs().filter { Self.host(of: $0.url).map { Self.matches(host: $0, domains: domains) } ?? false }
        // Last window and last tab first, so closing a window's only tab can't shift the indices still to close.
        for ref in doomed.sorted(by: { ($0.browser.rawValue, -$0.window, -$0.tab) < ($1.browser.rawValue, -$1.window, -$1.tab) }) {
            _ = try? scripts.run(tell(ref.browser, "close tab \(ref.tab) of window \(ref.window)"))
        }
        return doomed.count
    }

    public static func host(of url: String) -> String? {
        guard let h = URLComponents(string: url)?.host?.lowercased(), h.contains(".") else { return nil }
        return h
    }

    public static func matches(host: String, domains: Set<String>) -> Bool {
        domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    // MARK: Automation permission

    private static func status(for b: Browser, ask: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: b.rawValue)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, ask)
    }

    /// Asks macOS for permission (shows the system prompt once). The browser must be running.
    @discardableResult
    public static func requestAutomation(for b: Browser) -> Bool {
        status(for: b, ask: true) == noErr
    }

    public static func automationGranted(for b: Browser) -> Bool {
        status(for: b, ask: false) == noErr
    }

    /// True when an installed, running browser has not granted permission.
    public static var automationMissing: Bool {
        Browser.allCases.contains { systemIsRunning($0) && !automationGranted(for: $0) }
    }
}
