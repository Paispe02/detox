import AppKit
import Foundation
import Testing
@testable import DetoxAppKit

private final class Scripts: AppleScriptRunning {
    var calls: [String] = []
    var tabs: [[String]] = []
    func run(_ source: String) throws -> NSAppleEventDescriptor {
        calls.append(source)
        guard source.contains("every tab of every window") else { return .null() }
        let list = NSAppleEventDescriptor.list()
        for (i, w) in tabs.enumerated() {
            let inner = NSAppleEventDescriptor.list()
            for (j, u) in w.enumerated() { inner.insert(NSAppleEventDescriptor(string: u), at: j + 1) }
            list.insert(inner, at: i + 1)
        }
        return list
    }
}

@Test func sameAttemptIsNotShownAgainWithinFiveMinutes() {
    var g = RepeatGuard()
    let t = Date(timeIntervalSince1970: 0)
    let a = g.allow("https://www.youtube.com/watch?v=1", at: t)
    let b = g.allow("https://www.youtube.com/watch?v=1", at: t + 299)
    let c = g.allow("https://www.instagram.com/", at: t + 10)
    let d = g.allow("https://www.youtube.com/watch?v=1", at: t + 300)
    #expect(a && !b && c && d)
}

@Test func chromeTabsAreReloadedNotClosed() {
    let s = Scripts()
    s.tabs = [["https://mail.google.com/"], ["https://www.youtube.com/watch?v=1"]]
    let tabs = BrowserTabs(scripts: s, isRunning: { $0 == .chrome }, frontmostBundleID: { nil })
    #expect(tabs.reloadTabs(tabs.blockedTabs(matching: ["www.youtube.com"])) == 1)
    #expect(s.calls.contains { $0.contains("reload tab 1 of window 2") })
    #expect(!s.calls.contains { $0.contains("close") })
}

@Test func safariTabsAreReloadedByResettingTheirURL() {
    let s = Scripts()
    s.tabs = [["https://www.youtube.com/watch?v=1"]]
    let tabs = BrowserTabs(scripts: s, isRunning: { $0 == .safari }, frontmostBundleID: { nil })
    #expect(tabs.reloadTabs(tabs.blockedTabs(matching: ["www.youtube.com"])) == 1)
    #expect(s.calls.contains { $0.contains("set URL of tab 1 of window 1 to URL of tab 1 of window 1") })
    #expect(!s.calls.contains { $0.contains("close") })
}

@Test func silencerReloadsEachTabOnceUntilTheBlockChanges() {
    var s = TabSilencer()
    let yt = TabRef(browser: .chrome, window: 1, tab: 1, url: "https://www.youtube.com/watch?v=1")
    let first = s.pending([yt], blocked: ["www.youtube.com"])
    let again = s.pending([yt], blocked: ["www.youtube.com"])
    let over = s.pending([yt], blocked: [])                    // block over: nothing, memory cleared
    let nextNight = s.pending([yt], blocked: ["www.youtube.com"])
    #expect(first == [yt] && again.isEmpty && over.isEmpty && nextNight == [yt])
}
