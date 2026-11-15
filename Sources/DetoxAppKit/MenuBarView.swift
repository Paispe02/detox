import DetoxCore
import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var connection: DaemonConnection
    var automationMissing: Bool
    var onOpen: () -> Void
    var onFixPermission: () -> Void
    var onUnlock: (BlockView) -> Void

    public init(connection: DaemonConnection, automationMissing: Bool,
                onOpen: @escaping () -> Void, onFixPermission: @escaping () -> Void = {},
                onUnlock: @escaping (BlockView) -> Void) {
        self.connection = connection
        self.automationMissing = automationMissing
        self.onOpen = onOpen
        self.onFixPermission = onFixPermission
        self.onUnlock = onUnlock
    }

    private var live: [BlockView] {
        (connection.snapshot?.blocks ?? []).filter { $0.phase == .active || $0.phase == .paused }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(StatusSummary.headline(connection.snapshot, reachable: connection.isDaemonReachable)).font(Theme.title(19))
                if let d = StatusSummary.detail(connection.snapshot, reachable: connection.isDaemonReachable) {
                    Text(d).foregroundStyle(Theme.ivorySecondary)
                }
            }
            NightArc(bands: (connection.snapshot?.blocks ?? []).filter { $0.phase != .finished }.map(NightArc.Band.init),
                     now: connection.snapshot?.now ?? .now, compact: true)

            if !live.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(live) { b in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.name).fontWeight(.medium)
                                Text(liveDetail(b)).font(.callout).foregroundStyle(Theme.ivoryTertiary)
                            }
                            Spacer()
                            if b.phase == .active && b.lock != .noExit {
                                Button("Desbloquear…") { onUnlock(b) }.controlSize(.small)
                            } else if b.lock == .noExit {
                                Image(systemName: "lock.fill").foregroundStyle(Theme.gold)
                                    .help("Sin salida")
                            }
                        }
                    }
                }
            }

            if !connection.isDaemonReachable {
                Label("El servicio de Detox está desactivado.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.gold)
            }
            if automationMissing {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Detox no puede detener las pestañas bloqueadas: falta un permiso.", systemImage: "hand.raised.fill")
                        .font(.callout).foregroundStyle(Theme.ivorySecondary)
                    Button("Dar permiso…", action: onFixPermission).controlSize(.small)
                }
            }

            Divider().overlay(Theme.hairline)
            Button(action: onOpen) {
                Label("Abrir Detox", systemImage: "moon.stars")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o")
        }
        .padding(16)
        .frame(width: 320)
        .nightSurface()
    }

    private func liveDetail(_ b: BlockView) -> String {
        if b.phase == .paused, let until = b.pausedUntil { return "En pausa hasta las \(Formatting.clock(until))" }
        if let end = b.activeWindowEnd { return "Se abre a las \(Formatting.clock(end)) · \(Formatting.lockLabel(b.lock))" }
        return Formatting.lockLabel(b.lock)
    }
}
