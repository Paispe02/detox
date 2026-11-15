import AppKit
import Combine
import DetoxCore
import DetoxIPC
import SwiftUI

/// Wires daemon events to the intercept screen and to tab closing.
@MainActor
public final class AppModel: ObservableObject {
    public let connection: DaemonConnection
    public let presenter = InterceptWindowPresenter()
    private lazy var coordinator = InterceptCoordinator(presenter: presenter)
    private let tabs = BrowserTabs()
    private var repeatGuard = RepeatGuard()
    private var silencer = TabSilencer()
    private var tasks: [Task<Void, Never>] = []

    @Published public var editing: EditorTarget?
    @Published public var unlocking: BlockView?
    @Published public var showOnboarding = !AppSettings.hasOnboarded
    @Published public private(set) var automationMissing = false

    public enum EditorTarget: Identifiable {
        case new, edit(BlockView)
        public var id: String {
            switch self {
            case .new: return "new"
            case .edit(let b): return b.id.uuidString
            }
        }
        var block: BlockView? { if case .edit(let b) = self { return b } else { return nil } }
    }

    public convenience init(socketPath: String) {
        self.init(connection: DaemonConnection(client: DetoxClient(socketPath: socketPath)))
    }

    public init(connection: DaemonConnection) {
        self.connection = connection
    }

    public func start() {
        connection.start()
        let events = connection.events
        tasks.append(Task { [weak self] in
            for await e in events { self?.handle(e) }
        })
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self?.sweep()
            }
        })
    }

    private var blockedDomains: Set<String> { Set(connection.snapshot?.blockedDomainsNow ?? []) }

    private func handle(_ event: DaemonEvent) {
        switch event {
        case .attempt(let a):
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let automation = front.flatMap(Browser.init(rawValue:)).map(BrowserTabs.automationGranted(for:)) ?? false
            let frontURL = automation ? tabs.frontTabURL() : nil
            let show = AttemptPolicy.shouldShowScreen(event: a, frontmostBundleID: front,
                                                      frontTabHost: frontURL.flatMap(BrowserTabs.host(of:)),
                                                      automationAvailable: automation, blockedDomains: blockedDomains)
            let key: String
            switch a.target {
            case .app(let bundleID, _): key = "app:" + bundleID
            case .domain(let d): key = frontURL ?? "domain:" + d
            }
            if show && repeatGuard.allow(key, at: Date()) { coordinator.handle(content(for: a)) }
        case .windowStarted, .pauseEnded:
            silenceTabs()
        case .stateChanged:
            break
        }
    }

    private func sweep() {
        automationMissing = BrowserTabs.automationMissing
        silenceTabs()
    }

    /// Blocked tabs are reloaded once (the page can't load, a playing video stops); never closed.
    private func silenceTabs() {
        let domains = blockedDomains
        let pending = silencer.pending(domains.isEmpty ? [] : tabs.listTabs(), blocked: domains)
        if !pending.isEmpty { tabs.reloadTabs(pending) }
    }

    private func content(for a: AttemptEvent) -> InterceptContent {
        let name = a.blockNames.first ?? "Detox"
        let block = connection.snapshot?.blocks.first { a.blockIDs.contains($0.id) }
        let folder = AppSettings.videoFolder
        let videos = MediaLibrary.videos(in: folder), photos = MediaLibrary.photos(in: folder)
        var rng = SystemRandomNumberGenerator()
        switch InterceptPicker.pick(hasVideos: !videos.isEmpty, hasPhotos: !photos.isEmpty, using: &rng) {
        case .video: return .video(videos.randomElement()!, blockName: name)
        case .photo: return .photo(photos.randomElement()!, phrase: Phrases.random(), blockName: name, opensAt: block?.activeWindowEnd)
        case .calm: break
        }
        return .fallback(phrase: Phrases.random(), blockName: name, opensAt: block?.activeWindowEnd,
                         progress: block.map { ($0.progressCurrent, $0.progressTotal) }, window: block?.window)
    }

    // MARK: actions

    public func submit(_ draft: BlockDraft) async -> String? {
        let request: Request = editing?.block.map { .updateBlock(id: $0.id, draft: draft) } ?? .createBlock(draft)
        switch await connection.perform(request) {
        case .success:
            editing = nil
            await connection.refresh()
            return nil
        case .failure(let e):
            return e.userMessage
        }
    }

    public func unlock(_ block: BlockView, _ credential: UnlockCredential, _ action: UnlockAction) async -> String? {
        switch await connection.perform(.unlock(blockID: block.id, credential: credential, action: action)) {
        case .success:
            await connection.refresh()
            return nil
        case .failure(let e):
            await connection.refresh()
            return e.userMessage
        }
    }

    public func finishOnboarding() {
        AppSettings.hasOnboarded = true
        showOnboarding = false
    }
}
