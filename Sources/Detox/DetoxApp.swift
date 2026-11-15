import AppKit
import DetoxAppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel = {
        let socket = ProcessInfo.processInfo.environment["DETOX_SOCKET"] ?? "/var/run/detox.sock"
        return AppModel(socketPath: socket)
    }()
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        // At login launchd starts Detox with --background; opened from Aplicaciones/Finder it shows its window.
        if !CommandLine.arguments.contains("--background") || !AppSettings.hasOnboarded { showMain() }
    }

    /// Double-clicking Detox while it already runs: show the window instead of nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // The intercept screen can't be escaped with Cmd+Q before its 60 s.
        model.presenter.blocksTermination ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func showMain() {
        if mainWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Detox"
            w.titlebarAppearsTransparent = true
            w.backgroundColor = NSColor(Theme.night)
            w.appearance = NSAppearance(named: .darkAqua)
            w.isReleasedWhenClosed = false
            w.contentViewController = NSHostingController(rootView: RootView(model: model))
            w.setContentSize(NSSize(width: 900, height: 620))
            w.center()
            w.setFrameAutosaveName("DetoxMain")
            mainWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSLog("Detox: ventana principal visible=%d", mainWindow?.isVisible == true ? 1 : 0)
    }
}

@main
struct DetoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(connection: delegate.model.connection, automationMissing: delegate.model.automationMissing,
                        onOpen: { delegate.showMain() },
                        onFixPermission: { delegate.showMain(); delegate.model.showOnboarding = true },
                        onUnlock: { block in delegate.showMain(); delegate.model.unlocking = block })
        } label: {
            MenuBarIcon(connection: delegate.model.connection)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarIcon: View {
    @ObservedObject var connection: DaemonConnection

    var body: some View {
        let active = connection.snapshot?.blocks.contains { $0.phase == .active } ?? false
        return Image(systemName: !connection.isDaemonReachable ? "moon.zzz" : (active ? "moon.fill" : "moon"))
            .accessibilityLabel(active ? "Detox: bloqueo activo" : "Detox")
    }
}
