import DetoxCore
import SwiftUI

public struct BlockRow: View {
    let block: BlockView

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(block.name).font(Theme.title(17))
                    PhaseTag(phase: block.phase)
                }
                Text(Formatting.scheduleLabel(window: block.window, weekdays: block.weekdays))
                    .foregroundStyle(Theme.ivorySecondary)
                Text(targetsSummary(block.targets))
                    .font(.callout)
                    .foregroundStyle(Theme.ivoryTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 5) {
                Label(Formatting.lockLabel(block.lock), systemImage: lockSymbol(block.lock))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(block.lock == .noExit ? Theme.gold : Theme.ivorySecondary)
                Text(Formatting.dateRange(block.startDate, block.endDate))
                    .foregroundStyle(Theme.ivoryTertiary)
                if block.phase != .scheduled && block.phase != .finished {
                    Text("Noche \(block.progressCurrent) de \(block.progressTotal)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(Theme.ivoryTertiary)
                }
            }
            .font(.callout)
        }
        .padding(.vertical, 10)
        .opacity(block.phase == .finished ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }
}

public func lockSymbol(_ l: LockSummary) -> String {
    switch l {
    case .noExit: return "lock.fill"
    case .password: return "key.fill"
    case .friend: return "person.badge.key.fill"
    }
}

public func targetsSummary(_ t: BlockTargets) -> String {
    let names = ServiceCatalog.all.filter { t.services.contains($0.id) }.map(\.displayName)
        + t.domains.sorted() + t.apps.map(\.name).sorted()
    return names.joined(separator: " · ")
}

struct PhaseTag: View {
    let phase: BlockPhase

    var body: some View {
        Text(Formatting.phaseLabel(phase))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(phase == .active ? Theme.night : Theme.ivorySecondary)
            .background(Capsule().fill(phase == .active ? Theme.gold : Theme.nightHigh))
    }
}

/// Main window detail: the span you are inside, the night arc, then the blocks.
public struct BlocksListView: View {
    @ObservedObject var connection: DaemonConnection
    var onNew: () -> Void
    var onEdit: (BlockView) -> Void
    var onUnlock: (BlockView) -> Void

    public init(connection: DaemonConnection, onNew: @escaping () -> Void,
                onEdit: @escaping (BlockView) -> Void, onUnlock: @escaping (BlockView) -> Void) {
        self.connection = connection
        self.onNew = onNew
        self.onEdit = onEdit
        self.onUnlock = onUnlock
    }

    private var blocks: [BlockView] {
        let order: [BlockPhase: Int] = [.active: 0, .paused: 1, .running: 2, .scheduled: 3, .finished: 4]
        return (connection.snapshot?.blocks ?? []).sorted { (order[$0.phase] ?? 9, $0.name) < (order[$1.phase] ?? 9, $1.name) }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(StatusSummary.headline(connection.snapshot, reachable: connection.isDaemonReachable)).font(Theme.title(30))
                if let d = StatusSummary.detail(connection.snapshot, reachable: connection.isDaemonReachable) {
                    Text(d).font(.title3).foregroundStyle(Theme.ivorySecondary)
                }
            }
            .padding(.bottom, 22)

            NightArc(bands: blocks.filter { $0.phase != .finished }.map(NightArc.Band.init),
                     now: connection.snapshot?.now ?? .now)
                .padding(.bottom, 28)

            if !connection.isDaemonReachable { ServiceDownNotice().padding(.bottom, 16) }

            if connection.snapshot == nil {
                if connection.isDaemonReachable { ProgressView().controlSize(.small) }
            } else if blocks.isEmpty {
                EmptyBlocks(onNew: onNew)
            } else {
                List {
                    ForEach(blocks) { b in
                        BlockRow(block: b)
                            .contentShape(Rectangle())
                            .contextMenu {
                                if b.phase != .finished { Button("Editar…") { onEdit(b) } }
                                if b.phase == .active && b.lock != .noExit { Button("Desbloquear…") { onUnlock(b) } }
                            }
                            .onTapGesture(count: 2) { if b.phase != .finished { onEdit(b) } }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Theme.hairline)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNew) { Label("Nuevo bloqueo", systemImage: "plus") }
                    .help("Crear un bloqueo nuevo")
            }
        }
    }
}

struct EmptyBlocks: View {
    var onNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aún no hay ningún bloqueo.").font(Theme.title(20))
            Text("Elige qué quieres dejar fuera de tus noches, a qué horas y hasta cuándo.")
                .foregroundStyle(Theme.ivorySecondary)
            Button("Crear el primero", action: onNew)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(.top, 8)
    }
}

struct ServiceDownNotice: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("El servicio de Detox está desactivado.").fontWeight(.semibold)
                Text("Tus bloqueos no se están aplicando. Vuelve a instalarlo con scripts/install.sh.")
                    .foregroundStyle(Theme.ivorySecondary)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.gold)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.nightRaised))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1))
    }
}
