import AppKit
import DetoxAppKit
import DetoxCore
import DetoxIPC
import SwiftUI

// Renders Detox's screens with sample data (no daemon) to PNGs: detox-snapshots <out-dir>
let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".impeccable/review")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

var cal = Calendar.current
let now = cal.date(from: DateComponents(year: 2026, month: 12, day: 5, hour: 23, minute: 14))!
let ana = FriendView(id: UUID(), name: "Ana", isConfirmed: true, blockNames: ["Noches limpias"])
func block(_ name: String, _ services: Set<ServiceID>, _ w: DailyWindow, _ days: Set<Weekday>, _ lock: LockSummary,
           _ phase: BlockPhase, end: LocalDate, cur: Int, total: Int, domains: Set<String> = []) -> BlockView {
    BlockView(id: UUID(), name: name, targets: BlockTargets(services: services, domains: domains), window: w, weekdays: days,
              startDate: LocalDate(2026, 12, 1), endDate: end, timeZoneID: "Europe/Madrid", lock: lock, pauseMinutes: 15,
              phase: phase, pausedUntil: nil,
              activeWindowEnd: phase == .active ? cal.date(from: DateComponents(year: 2026, month: 12, day: 6, hour: 6))! : nil,
              nextWindowStart: phase == .running ? cal.date(from: DateComponents(year: 2026, month: 12, day: 6, hour: 22, minute: 30)) : nil,
              commitmentEnd: now, progressCurrent: cur, progressTotal: total)
}
let night = DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0))
let snapshot = StatusSnapshot(now: now, isTrustedTime: true, blocks: [
    block("Noches limpias", [.instagram, .youtube], night, Set(Weekday.allCases), .noExit, .active, end: LocalDate(2026, 12, 31), cur: 5, total: 31),
    block("WhatsApp de noche", [.whatsapp], DailyWindow(start: LocalTime(23, 0), end: LocalTime(7, 0)), Set(Weekday.allCases), .password, .active, end: LocalDate(2026, 12, 31), cur: 5, total: 31),
    block("Fines de semana", [.tiktok], DailyWindow(start: LocalTime(21, 0), end: LocalTime(9, 0)), [.saturday, .sunday], .friend(id: ana.id, name: "Ana"), .running, end: LocalDate(2027, 1, 31), cur: 1, total: 18, domains: ["twitch.tv"]),
], friends: [ana], blockedDomainsNow: ["www.youtube.com"], rateLimitedUntil: nil)

final class Canned: DaemonClienting, @unchecked Sendable {
    let s: StatusSnapshot?
    init(_ s: StatusSnapshot?) { self.s = s }
    func send(_ request: Request) async throws -> Response {
        guard let s else { throw CancellationError() }
        return .status(s)
    }
    func events() -> AsyncThrowingStream<DaemonEvent, Error> { AsyncThrowingStream { _ in } }
}

@MainActor func render<V: View>(_ name: String, _ size: CGSize, _ view: V) {
    let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
    host.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    window.appearance = NSAppearance(named: .darkAqua)
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(name).png"))
    print("wrote \(name).png")
}

MainActor.assumeIsolated {
    NSApplication.shared.setActivationPolicy(.accessory)
    let live = DaemonConnection(client: Canned(snapshot))
    let empty = DaemonConnection(client: Canned(StatusSnapshot(now: now, isTrustedTime: true, blocks: [], friends: [], blockedDomainsNow: [], rateLimitedUntil: nil)))
    let down = DaemonConnection(client: Canned(nil))
    let group = DispatchGroup()
    group.enter()
    Task { @MainActor in
        await live.refresh(); await empty.refresh(); await down.refresh()
        AppSettings.hasOnboarded = true
        render("main-blocks", CGSize(width: 1000, height: 640), RootView(model: { let m = AppModel(socketPath: "/nonexistent"); return m }()).environmentObject(live))
        render("blocks-list", CGSize(width: 820, height: 640), BlocksListView(connection: live, onNew: {}, onEdit: { _ in }, onUnlock: { _ in }).nightSurface())
        render("blocks-empty", CGSize(width: 820, height: 480), BlocksListView(connection: empty, onNew: {}, onEdit: { _ in }, onUnlock: { _ in }).nightSurface())
        render("blocks-daemon-down", CGSize(width: 820, height: 480), BlocksListView(connection: down, onNew: {}, onEdit: { _ in }, onUnlock: { _ in }).nightSurface())
        render("menubar", CGSize(width: 320, height: 330), MenuBarView(connection: live, automationMissing: true, onOpen: {}, onUnlock: { _ in }))
        render("friends", CGSize(width: 820, height: 560), FriendsView(connection: live).nightSurface())
        render("editor-new", CGSize(width: 560, height: 560), BlockEditorView(existing: nil, friends: [ana], now: now, onSubmit: { _ in nil }, onCancel: {}))
        render("editor-running", CGSize(width: 560, height: 560), BlockEditorView(existing: snapshot.blocks[2], friends: [ana], now: now, onSubmit: { _ in nil }, onCancel: {}))
        render("unlock-password", CGSize(width: 420, height: 300), UnlockView(block: snapshot.blocks[1], rateLimitedUntil: nil, onUnlock: { _, _ in nil }, onClose: {}))
        render("unlock-friend", CGSize(width: 420, height: 400), UnlockView(block: snapshot.blocks[2], rateLimitedUntil: nil, onUnlock: { _, _ in nil }, onClose: {}))
        render("onboarding", CGSize(width: 520, height: 600), OnboardingView(onDone: {}))
        render("intercept", CGSize(width: 1440, height: 900), InterceptPreview.calm(blockName: "Noches limpias", opensAt: snapshot.blocks[0].activeWindowEnd, progress: (5, 31)))
        render("settings", CGSize(width: 700, height: 420), SettingsView().nightSurface())
        group.leave()
    }
    while group.wait(timeout: .now()) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
}
