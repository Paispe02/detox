import DetoxCore
import DetoxIPC
import SwiftUI

public struct UnlockView: View {
    let block: BlockView
    let rateLimitedUntil: Date?
    let onUnlock: (UnlockCredential, UnlockAction) async -> String?
    let onClose: () -> Void

    @State private var secret = ""
    @State private var action: UnlockAction = .pause
    @State private var error: String?
    @State private var working = false

    public init(block: BlockView, rateLimitedUntil: Date?,
                onUnlock: @escaping (UnlockCredential, UnlockAction) async -> String?, onClose: @escaping () -> Void) {
        self.block = block
        self.rateLimitedUntil = rateLimitedUntil
        self.onUnlock = onUnlock
        self.onClose = onClose
    }

    private var friendName: String? {
        if case .friend(_, let name) = block.lock { return name }
        return nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Desbloquear «\(block.name)»").font(Theme.title(22))
            if let end = block.activeWindowEnd {
                Text("Se abre solo a las \(Formatting.clock(end)). ¿De verdad lo necesitas ahora?")
                    .foregroundStyle(Theme.ivorySecondary)
            }
            if let name = friendName {
                Label("Llama a \(name) y pídele el código.", systemImage: "phone.fill")
                TextField("Código de 6 cifras", text: $secret)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2.monospacedDigit())
                Picker("Qué hacer", selection: $action) {
                    Text("Pausa de \(block.pauseMinutes) min").tag(UnlockAction.pause)
                    Text("Cancelar el bloqueo").tag(UnlockAction.cancel)
                }
                .pickerStyle(.radioGroup)
            } else {
                SecureField("Contraseña", text: $secret).textFieldStyle(.roundedBorder)
                Text("Tendrás \(block.pauseMinutes) minutos. Después vuelve a bloquear y las pestañas bloqueadas se detienen.")
                    .font(.callout).foregroundStyle(Theme.ivoryTertiary)
            }
            if let until = rateLimitedUntil, until > .now {
                Text(CommandError.rateLimited(until: until).userMessage).foregroundStyle(Theme.gold)
            }
            if let error { Text(error).foregroundStyle(Theme.gold) }
            HStack {
                Button("Mejor no", role: .cancel, action: onClose).keyboardShortcut(.cancelAction)
                Spacer()
                Button(action == .cancel ? "Cancelar bloqueo" : "Desbloquear") {
                    Task {
                        working = true
                        let cred: UnlockCredential = friendName != nil ? .friendCode(secret) : .password(secret)
                        error = await onUnlock(cred, friendName != nil ? action : .pause)
                        working = false
                        if error == nil { onClose() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(secret.isEmpty || working)
            }
        }
        .padding(24)
        .frame(width: 420)
        .nightSurface()
    }
}
