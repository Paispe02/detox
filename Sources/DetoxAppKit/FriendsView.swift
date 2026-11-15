import CoreImage.CIFilterBuiltins
import DetoxCore
import DetoxIPC
import SwiftUI

public enum QRCode {
    public static func image(for string: String, scale: CGFloat = 10) -> NSImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(string.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        let rep = NSCIImageRep(ciImage: out)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }
}

public struct FriendsView: View {
    @ObservedObject var connection: DaemonConnection
    @State private var newName = ""
    @State private var provisioning: FriendProvisioning?
    @State private var code = ""
    @State private var message: String?

    public init(connection: DaemonConnection) {
        self.connection = connection
    }

    private var friends: [FriendView] { connection.snapshot?.friends ?? [] }

    private func inUse(_ f: FriendView) -> Bool {
        let busy: Set<BlockPhase> = [.scheduled, .running, .active, .paused]
        return (connection.snapshot?.blocks ?? []).contains {
            if case .friend(let id, _) = $0.lock { return id == f.id && busy.contains($0.phase) }
            return false
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Amigos").font(Theme.title(30))
                Text("Una persona de confianza guarda en su móvil la llave de tus bloqueos. Cuando la necesites, le llamas y te dicta el código del momento.")
                    .foregroundStyle(Theme.ivorySecondary)
                    .frame(maxWidth: 560, alignment: .leading)
            }

            if let p = provisioning {
                registration(p)
            } else {
                HStack {
                    TextField("Nombre de tu amigo", text: $newName).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    Button("Registrar") {
                        Task {
                            switch await connection.perform(.registerFriend(name: newName)) {
                            case .success(.friendProvisioning(let p)): provisioning = p; message = nil
                            case .failure(let e): message = e.userMessage
                            default: break
                            }
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let message { Text(message).foregroundStyle(Theme.gold) }

            if friends.isEmpty {
                Text("Todavía no hay nadie registrado.").foregroundStyle(Theme.ivoryTertiary)
            } else {
                List(friends) { f in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(f.name).font(Theme.title(16))
                            Text(f.isConfirmed
                                 ? (f.blockNames.isEmpty ? "Sin bloqueos" : "Llave de: " + f.blockNames.joined(separator: ", "))
                                 : "Sin confirmar")
                                .font(.callout).foregroundStyle(Theme.ivoryTertiary)
                        }
                        Spacer()
                        Button("Quitar", role: .destructive) {
                            Task {
                                if case .failure(let e) = await connection.perform(.deleteFriend(id: f.id)) { message = e.userMessage }
                                await connection.refresh()
                            }
                        }
                        .disabled(inUse(f))
                        .help(inUse(f) ? "Tiene la llave de un bloqueo en marcha" : "Quitar a \(f.name)")
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func registration(_ p: FriendProvisioning) -> some View {
        HStack(alignment: .top, spacing: 24) {
            if let img = QRCode.image(for: p.uri) {
                Image(nsImage: img)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Código QR para \(p.name)")
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Que lo escanee \(p.name)").font(Theme.title(18))
                Text("Con la app Contraseñas del iPhone o Google Authenticator. No lo fotografíes tú: este código solo se muestra una vez.")
                    .foregroundStyle(Theme.ivorySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Después, \(p.name) te dice el código de 6 cifras que le aparece:")
                TextField("123 456", text: $code).textFieldStyle(.roundedBorder).font(.title3.monospacedDigit()).frame(width: 160)
                HStack {
                    Button("Confirmar") {
                        Task {
                            switch await connection.perform(.confirmFriend(id: p.friendID, code: code)) {
                            case .success:
                                provisioning = nil; code = ""; newName = ""; message = "\(p.name) ya tiene su llave."
                                await connection.refresh()
                            case .failure(let e): message = e.userMessage
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(code.filter(\.isNumber).count != 6)
                    Button("Cancelar") {
                        Task {
                            _ = await connection.perform(.deleteFriend(id: p.friendID))
                            provisioning = nil; code = ""
                            await connection.refresh()
                        }
                    }
                }
            }
            .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.nightRaised))
    }
}
