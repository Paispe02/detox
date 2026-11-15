import AppKit
import DetoxCore
import DetoxIPC
import Foundation
import Testing
@testable import DetoxAppKit

// MARK: BrowserTabs

private final class FakeScripts: AppleScriptRunning {
    var calls: [String] = []
    var tabs: [[String]] = []          // per window, URLs
    var front: String?

    func run(_ source: String) throws -> NSAppleEventDescriptor {
        calls.append(source)
        if source.contains("every tab of every window") {
            let list = NSAppleEventDescriptor.list()
            for (i, window) in tabs.enumerated() {
                let inner = NSAppleEventDescriptor.list()
                for (j, url) in window.enumerated() { inner.insert(NSAppleEventDescriptor(string: url), at: j + 1) }
                list.insert(inner, at: i + 1)
            }
            return list
        }
        if source.contains("front window") { return NSAppleEventDescriptor(string: front ?? "") }
        return NSAppleEventDescriptor.null()
    }
}

@Test func neverScriptsABrowserThatIsNotRunning() {
    let scripts = FakeScripts()
    let tabs = BrowserTabs(scripts: scripts, isRunning: { _ in false }, frontmostBundleID: { "com.apple.Safari" })
    #expect(tabs.frontTabHost() == nil)
    #expect(tabs.listTabs().isEmpty)
    #expect(tabs.closeTabs(matching: ["youtube.com"]) == 0)
    #expect(scripts.calls.isEmpty)
}

@Test func closesOnlyMatchingTabs() {
    let scripts = FakeScripts()
    scripts.tabs = [["https://www.youtube.com/watch?v=1", "https://mail.google.com/", "https://www.google.com/search?q=youtube.com"]]
    let tabs = BrowserTabs(scripts: scripts, isRunning: { $0 == .safari }, frontmostBundleID: { nil })
    #expect(tabs.closeTabs(matching: ["www.youtube.com", "youtube.com"]) == 1)
    let closes = scripts.calls.filter { $0.contains("close tab") }
    #expect(closes.count == 1 && closes[0].contains("close tab 1 of window 1"))
    #expect(scripts.calls.allSatisfy { $0.contains("tell application id \"com.apple.Safari\"") })
}

@Test func closesInReverseOrderWithinWindow() {
    let scripts = FakeScripts()
    scripts.tabs = [["https://youtube.com/a", "https://example.com", "https://m.youtube.com/b"]]
    let tabs = BrowserTabs(scripts: scripts, isRunning: { $0 == .chrome }, frontmostBundleID: { nil })
    #expect(tabs.closeTabs(matching: ["youtube.com"]) == 2)
    let closes = scripts.calls.filter { $0.contains("close tab") }
    #expect(closes[0].contains("close tab 3 of window 1") && closes[1].contains("close tab 1 of window 1"))
}

@Test func subdomainMatching() {
    #expect(BrowserTabs.matches(host: "m.youtube.com", domains: ["youtube.com"]))
    #expect(BrowserTabs.matches(host: "youtube.com", domains: ["youtube.com"]))
    #expect(!BrowserTabs.matches(host: "notyoutube.com", domains: ["youtube.com"]))
    #expect(BrowserTabs.host(of: "https://WWW.YouTube.com:443/watch?v=1") == "www.youtube.com")
    #expect(BrowserTabs.host(of: "favorites://") == nil)
}

@Test func frontTabHostReadsFrontBrowser() {
    let scripts = FakeScripts()
    scripts.front = "https://www.instagram.com/explore/"
    let tabs = BrowserTabs(scripts: scripts, isRunning: { _ in true }, frontmostBundleID: { "com.google.Chrome" })
    #expect(tabs.frontTabHost() == "www.instagram.com")
    #expect(scripts.calls.last?.contains("active tab of front window") == true)
}

// MARK: AttemptPolicy

private func domainEvent(_ host: String, primary: Bool) -> AttemptEvent {
    AttemptEvent(target: .domain(host), blockIDs: [UUID()], blockNames: ["Noches"], isPrimaryDomain: primary, at: .now)
}

@Test func pixelOnOtherSiteDoesNotShowScreen() {
    #expect(!AttemptPolicy.shouldShowScreen(event: domainEvent("www.facebook.com", primary: true),
                                            frontmostBundleID: "com.apple.Safari", frontTabHost: "elpais.com",
                                            automationAvailable: true, blockedDomains: ["www.facebook.com"]))
}

@Test func frontTabOnBlockedSiteShowsScreen() {
    #expect(AttemptPolicy.shouldShowScreen(event: domainEvent("www.youtube.com", primary: true),
                                           frontmostBundleID: "com.google.Chrome", frontTabHost: "www.youtube.com",
                                           automationAvailable: true, blockedDomains: ["www.youtube.com"]))
}

@Test func fallbackPrimaryShows() {
    #expect(AttemptPolicy.shouldShowScreen(event: domainEvent("www.instagram.com", primary: true),
                                           frontmostBundleID: "com.apple.Safari", frontTabHost: nil,
                                           automationAvailable: false, blockedDomains: []))
}

@Test func fallbackSecondaryIsSilent() {
    #expect(!AttemptPolicy.shouldShowScreen(event: domainEvent("i.ytimg.com", primary: false),
                                            frontmostBundleID: "com.apple.Safari", frontTabHost: nil,
                                            automationAvailable: false, blockedDomains: []))
}

@Test func nonBrowserFrontmostIsSilent() {
    #expect(!AttemptPolicy.shouldShowScreen(event: domainEvent("www.instagram.com", primary: true),
                                            frontmostBundleID: "com.apple.mail", frontTabHost: nil,
                                            automationAvailable: false, blockedDomains: []))
}

@Test func appAttemptAlwaysShows() {
    let e = AttemptEvent(target: .app(bundleID: "net.whatsapp.WhatsApp", name: "WhatsApp"), blockIDs: [], blockNames: [],
                         isPrimaryDomain: false, at: .now)
    #expect(AttemptPolicy.shouldShowScreen(event: e, frontmostBundleID: nil, frontTabHost: nil,
                                           automationAvailable: false, blockedDomains: []))
}

// MARK: Timing and coordinator

@Test func canCloseAfter60sOrVideoEnd() {
    #expect(!InterceptTiming.canClose(elapsed: 59, videoEnded: false))
    #expect(InterceptTiming.canClose(elapsed: 60, videoEnded: false))
    #expect(InterceptTiming.canClose(elapsed: 10, videoEnded: true))
}

@MainActor private final class FakePresenter: InterceptPresenting {
    var shown: [InterceptContent] = []
    var dismiss: (() -> Void)?
    func present(_ content: InterceptContent, onDismiss: @escaping () -> Void) {
        shown.append(content)
        dismiss = onDismiss
    }
}

private let content = InterceptContent.fallback(phrase: "x", blockName: "Noches", opensAt: nil, progress: nil)

@MainActor @Test func secondAttemptWhileShowingIsIgnored() {
    let p = FakePresenter()
    var now = Date(timeIntervalSince1970: 0)
    let c = InterceptCoordinator(presenter: p, now: { now })
    c.handle(content)
    now += 5
    c.handle(content)
    #expect(p.shown.count == 1 && c.isShowing)
}

@MainActor @Test func attemptDuringCooldownIgnored() {
    let p = FakePresenter()
    var now = Date(timeIntervalSince1970: 0)
    let c = InterceptCoordinator(presenter: p, now: { now })
    c.handle(content)
    now += 70
    p.dismiss?()
    now += 19
    c.handle(content)
    #expect(p.shown.count == 1 && !c.isShowing)
}

@MainActor @Test func attemptAfterCooldownShows() {
    let p = FakePresenter()
    var now = Date(timeIntervalSince1970: 0)
    let c = InterceptCoordinator(presenter: p, now: { now })
    c.handle(content)
    now += 70
    p.dismiss?()
    now += 20
    c.handle(content)
    #expect(p.shown.count == 2)
}

// MARK: Videos and phrases

@Test func videoLibraryListsOnlyVideos() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vids-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for f in ["a.MP4", "b.mov", "c.txt", ".hidden.mp4"] { try Data().write(to: dir.appendingPathComponent(f)) }
    #expect(VideoLibrary.videos(in: dir).map(\.lastPathComponent).sorted() == ["a.MP4", "b.mov"])
    #expect(VideoLibrary.randomVideo(in: dir) != nil)
    #expect(VideoLibrary.videos(in: dir.appendingPathComponent("nope")).isEmpty)
}

@Test func phrasesAreUniqueAndEnough() {
    #expect(Phrases.all.count >= 20)
    #expect(Set(Phrases.all).count == Phrases.all.count)
}

@Test func closesWindowsFromLastToFirst() {
    let scripts = FakeScripts()
    scripts.tabs = [["https://www.instagram.com/"], ["https://mail.google.com/", "https://www.youtube.com/"], ["https://docs.example.com/"]]
    let tabs = BrowserTabs(scripts: scripts, isRunning: { $0 == .safari }, frontmostBundleID: { nil })
    #expect(tabs.closeTabs(matching: ["www.instagram.com", "www.youtube.com"]) == 2)
    let closes = scripts.calls.filter { $0.contains("close tab") }
    #expect(closes.count == 2 && closes[0].contains("close tab 2 of window 2") && closes[1].contains("close tab 1 of window 1"))
}
