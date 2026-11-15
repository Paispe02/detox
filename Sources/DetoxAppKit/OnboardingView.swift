import AppKit
import SwiftUI

public struct OnboardingView: View {
    let onDone: () -> Void
    @State private var granted: [Browser: Bool] = [:]

    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    private var installed: [Browser] {
        Browser.allCases.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.rawValue) != nil }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon).resizable().frame(width: 64, height: 64)
            }
            Text("Tus noches, protegidas").font(Theme.title(28))
            Text("Detox bloquea las webs y apps que elijas, a las horas que elijas, entre dos fechas. Cuando intentes entrar, en vez de la web verás uno de tus vídeos o una pausa para respirar.")
                .foregroundStyle(Theme.ivorySecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Un permiso más").font(.headline)
            Text("Para saber si la web bloqueada es la pestaña que tienes delante, y para cerrar las pestañas bloqueadas cuando empieza tu horario, Detox necesita permiso para controlar tus navegadores. macOS te lo preguntará una vez por navegador; el navegador debe estar abierto.")
                .foregroundStyle(Theme.ivorySecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(installed, id: \.self) { b in
                HStack {
                    Text(b == .safari ? "Safari" : "Google Chrome")
                    Spacer()
                    if granted[b] == true {
                        Label("Permitido", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.gold)
                    } else {
                        Button("Pedir permiso") {
                            if !BrowserTabs.systemIsRunning(b), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b.rawValue) {
                                NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { ask(b) }
                                }
                            } else {
                                ask(b)
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.nightRaised))
            }
            HStack {
                Spacer()
                Button(installed.allSatisfy { granted[$0] == true } ? "Empezar" : "Hacerlo más tarde", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 520)
        .nightSurface()
        .onAppear {
            for b in installed { granted[b] = BrowserTabs.systemIsRunning(b) && BrowserTabs.automationGranted(for: b) }
        }
    }

    private func ask(_ b: Browser) {
        DispatchQueue.global().async {
            let ok = BrowserTabs.requestAutomation(for: b)
            DispatchQueue.main.async { granted[b] = ok }
        }
    }
}
