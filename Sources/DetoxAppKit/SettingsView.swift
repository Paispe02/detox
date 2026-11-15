import AppKit
import SwiftUI

public struct SettingsView: View {
    @State private var folder = AppSettings.videoFolder
    @State private var videoCount = 0

    public init() {}

    public var body: some View {
        Form {
            Section {
                LabeledContent("Carpeta") {
                    HStack {
                        Text(folder.path(percentEncoded: false)).lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(Theme.ivorySecondary)
                        Button("Cambiar…", action: choose)
                        Button("Mostrar") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                    }
                }
                Text(videoCount == 0
                     ? "No hay vídeos: al intentar entrar verás una pausa de respiración. Añade .mp4, .mov o .m4v para que salga uno al azar."
                     : "\(videoCount) \(videoCount == 1 ? "vídeo" : "vídeos") listos. Sale uno al azar en cada intento.")
                    .font(.callout)
                    .foregroundStyle(Theme.ivoryTertiary)
            } header: {
                Text("Vídeos motivadores").font(Theme.title(15))
            }
            Section {
                Text("Detox hace incómodo saltarse un bloqueo, no imposible: con la contraseña de administrador y la terminal se puede desactivar. Si quieres que sea inquebrantable, convierte tu cuenta en estándar y deja la contraseña de administrador a otra persona. Los pasos están en el README.")
                    .font(.callout)
                    .foregroundStyle(Theme.ivorySecondary)
            } header: {
                Text("Límites").font(Theme.title(15))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear(perform: count)
    }

    private func count() {
        videoCount = VideoLibrary.videos(in: folder).count
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = folder
        panel.prompt = "Usar esta carpeta"
        if panel.runModal() == .OK, let url = panel.url {
            AppSettings.videoFolder = url
            folder = url
            count()
        }
    }
}
