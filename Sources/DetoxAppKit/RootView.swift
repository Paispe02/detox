import SwiftUI

public struct RootView: View {
    enum Section: String, Hashable, CaseIterable {
        case blocks = "Bloqueos", friends = "Amigos", settings = "Ajustes"
        var symbol: String {
            switch self {
            case .blocks: return "moon.stars"
            case .friends: return "person.2"
            case .settings: return "gearshape"
            }
        }
    }

    @ObservedObject var model: AppModel
    @ObservedObject var connection: DaemonConnection
    @State private var section: Section? = .blocks

    public init(model: AppModel) {
        self.model = model
        self.connection = model.connection
    }

    public var body: some View {
        NavigationSplitView {
            List(Section.allCases, id: \.self, selection: $section) { s in
                Label(s.rawValue, systemImage: s.symbol)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .scrollContentBackground(.hidden)
            .background(Theme.nightRaised)
            .tint(Theme.gold)
        } detail: {
            Group {
                switch section ?? .blocks {
                case .blocks:
                    BlocksListView(connection: connection,
                                   onNew: { model.editing = .new },
                                   onEdit: { model.editing = .edit($0) },
                                   onUnlock: { model.unlocking = $0 })
                case .friends:
                    FriendsView(connection: connection)
                case .settings:
                    SettingsView().padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.night)
        }
        .frame(minWidth: 760, minHeight: 520)
        .toolbarBackground(Theme.night, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .accentColor(Theme.gold)
        .nightSurface()
        .sheet(item: $model.editing) { target in
            BlockEditorView(existing: target.block, friends: connection.snapshot?.friends ?? [],
                            now: connection.snapshot?.now ?? .now,
                            onSubmit: { await model.submit($0) },
                            onCancel: { model.editing = nil })
        }
        .sheet(item: $model.unlocking) { block in
            UnlockView(block: block, rateLimitedUntil: connection.snapshot?.rateLimitedUntil,
                       onUnlock: { await model.unlock(block, $0, $1) },
                       onClose: { model.unlocking = nil })
        }
        .sheet(isPresented: $model.showOnboarding) {
            OnboardingView(onDone: model.finishOnboarding)
        }
    }
}
