import AppKit
import DetoxAppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // The intercept screen can't be escaped with Cmd+Q before its 60 s.
        MainActor.assumeIsolated { model?.presenter.blocksTermination == true } ? .terminateCancel : .terminateNow
    }
}

@main
struct DetoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    init() {
        let socket = ProcessInfo.processInfo.environment["DETOX_SOCKET"] ?? "/var/run/detox.sock"
        let m = AppModel(socketPath: socket)
        _model = StateObject(wrappedValue: m)
        m.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(connection: model.connection, automationMissing: model.automationMissing,
                        onOpen: { openMain() },
                        onFixPermission: { openMain(); model.showOnboarding = true },
                        onUnlock: { block in openMain(); model.unlocking = block })
                .onAppear { delegate.model = model }
        } label: {
            MenuBarIcon(connection: model.connection)
        }
        .menuBarExtraStyle(.window)

        Window("Detox", id: "main") {
            RootView(model: model)
                .onAppear { delegate.model = model }
        }
        .defaultSize(width: 900, height: 620)
        .windowToolbarStyle(.unified)
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MenuBarIcon: View {
    @ObservedObject var connection: DaemonConnection

    var body: some View {
        let active = connection.snapshot?.blocks.contains { $0.phase == .active } ?? false
        Image(systemName: !connection.isDaemonReachable ? "moon.zzz" : (active ? "moon.fill" : "moon"))
            .accessibilityLabel(active ? "Detox: bloqueo activo" : "Detox")
    }
}
