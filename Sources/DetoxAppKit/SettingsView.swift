import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @State private var folder = AppSettings.videoFolder
    @State private var videoCount = 0
    @State private var photoCount = 0

    public init() {}

    public var body: some View {
        Form {
            Section {
                LabeledContent("Carpeta") {
                    HStack {
                        Text(folder.path(percentEncoded: false)).lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(Theme.ivorySecondary)
                        Button("Añadir…", action: addFiles)
                        Button("Cambiar…", action: choose)
                        Button("Mostrar") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                    }
                }
                Text("\(videoCount) \(videoCount == 1 ? "vídeo" : "vídeos") y \(photoCount) \(photoCount == 1 ? "foto" : "fotos"). En cada intento sale al azar un vídeo, una foto con una frase o la pausa de respiración. Añade más con «Añadir…» o arrastrándolos a la carpeta.")
                    .font(.callout)
                    .foregroundStyle(Theme.ivoryTertiary)
            } header: {
                Text("Vídeos y fotos").font(Theme.title(15))
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
        videoCount = MediaLibrary.videos(in: folder).count
        photoCount = MediaLibrary.photos(in: folder).count
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .image]
        panel.prompt = "Añadir"
        if panel.runModal() == .OK {
            MediaLibrary.add(panel.urls, to: folder)
            count()
        }
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
