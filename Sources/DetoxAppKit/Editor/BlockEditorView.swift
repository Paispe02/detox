import AppKit
import DetoxCore
import SwiftUI
import UniformTypeIdentifiers

/// Step-by-step: Qué → Horario → Fechas → Cerradura → Confirmar.
public struct BlockEditorView: View {
    enum Step: Int, CaseIterable {
        case what, when, dates, lock, confirm
        var title: String {
            switch self {
            case .what: return "Qué bloquear"
            case .when: return "Horario"
            case .dates: return "Fechas"
            case .lock: return "Cerradura"
            case .confirm: return "Confirmar"
            }
        }
    }

    @StateObject private var model: EditorModel
    @State private var step: Step = .what
    @State private var domainError: String?
    @State private var submitError: String?
    @State private var submitting = false
    private let onSubmit: (BlockDraft) async -> String?
    private let onCancel: () -> Void

    public init(existing: BlockView?, friends: [FriendView], now: Date,
                onSubmit: @escaping (BlockDraft) async -> String?, onCancel: @escaping () -> Void) {
        _model = StateObject(wrappedValue: EditorModel(existing: existing, friends: friends, now: now))
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.hairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case .what: whatStep
                    case .when: whenStep
                    case .dates: datesStep
                    case .lock: lockStep
                    case .confirm: confirmStep
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider().overlay(Theme.hairline)
            footer
        }
        .frame(width: 560, height: 560)
        .nightSurface()
    }

    // MARK: chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.existing == nil ? "Nuevo bloqueo" : (model.isRunning ? "Endurecer «\(model.existing!.name)»" : "Editar bloqueo"))
                .font(Theme.title(22))
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.gold : Theme.nightHigh)
                        .frame(height: 3)
                }
            }
            Text(step.title).font(.callout).foregroundStyle(Theme.ivorySecondary)
            if model.isRunning {
                Text("Está en marcha: solo puedes hacerlo más estricto.")
                    .font(.callout).foregroundStyle(Theme.gold)
            }
        }
        .padding(24)
    }

    private var footer: some View {
        HStack {
            Button("Cancelar", role: .cancel, action: onCancel).keyboardShortcut(.cancelAction)
            Spacer()
            if let msg = submitError ?? (step == .confirm ? model.validationMessage : nil) {
                Text(msg).font(.callout).foregroundStyle(Theme.gold).lineLimit(2)
            }
            if step != .what {
                Button("Atrás") { step = Step(rawValue: step.rawValue - 1)! }
            }
            if step == .confirm {
                Button(model.existing == nil ? "Crear bloqueo" : "Guardar") {
                    Task {
                        submitting = true
                        submitError = await onSubmit(model.makeDraft())
                        submitting = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSubmit || submitting)
            } else {
                Button("Siguiente") { step = Step(rawValue: step.rawValue + 1)! }
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == .what && model.draft.targets.isEmpty)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: steps

    private var whatStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("Nombre", text: $model.draft.name)
                .textFieldStyle(.roundedBorder)
                .font(Theme.title(16))
            Text("Servicios").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(ServiceCatalog.all, id: \.id) { s in
                    Toggle(s.displayName, isOn: Binding(
                        get: { model.draft.targets.services.contains(s.id) },
                        set: { _ in model.toggle(service: s.id) }))
                        .toggleStyle(.checkbox)
                        .disabled(!model.canRemove(service: s.id))
                }
            }
            Text("Otras webs").font(.headline)
            HStack {
                TextField("Por ejemplo twitch.tv", text: $model.customDomainInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addDomain)
                Button("Añadir", action: addDomain).disabled(model.customDomainInput.isEmpty)
            }
            if let domainError { Text(domainError).font(.callout).foregroundStyle(Theme.gold) }
            chips(model.draft.targets.domains.sorted(), canRemove: model.canRemove(domain:)) {
                model.draft.targets.domains.remove($0)
            }
            Text("Apps").font(.headline)
            HStack {
                Button("Elegir app…", action: chooseApp)
                Text("Se cerrará en cuanto la abras durante el horario.").font(.callout).foregroundStyle(Theme.ivoryTertiary)
            }
            chips(model.draft.targets.apps.map(\.name).sorted(), canRemove: { name in
                model.draft.targets.apps.first { $0.name == name }.map(model.canRemove(app:)) ?? true
            }) { name in
                model.draft.targets.apps = model.draft.targets.apps.filter { $0.name != name }
            }
        }
    }

    private var whenStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 24) {
                timePicker("Desde", $model.draft.window.start)
                timePicker("Hasta", $model.draft.window.end)
            }
            NightArc(bands: [NightArc.Band(id: UUID(), window: model.draft.window, isActive: true)], now: .now)
            Text(model.draft.window.crossesMidnight ? "Noches de" : "Días").font(.headline)
            HStack(spacing: 8) {
                ForEach(Formatting.weekdayOrder, id: \.self) { d in
                    let on = model.draft.weekdays.contains(d)
                    let locked = model.isRunning && model.existing!.weekdays.contains(d)
                    Toggle(Formatting.letters[d]!, isOn: Binding(
                        get: { on },
                        set: { v in if v { model.draft.weekdays.insert(d) } else if !locked { model.draft.weekdays.remove(d) } }))
                        .toggleStyle(.button)
                        .disabled(locked)
                        .accessibilityLabel(dayName(d))
                }
            }
            Text(Formatting.scheduleLabel(window: model.draft.window, weekdays: model.draft.weekdays))
                .foregroundStyle(Theme.ivorySecondary)
            if model.isRunning {
                Text("Puedes empezar antes o terminar más tarde, pero no acortar la franja.")
                    .font(.callout).foregroundStyle(Theme.ivoryTertiary)
            }
        }
    }

    private var datesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            DatePicker("Empieza", selection: localDate($model.draft.startDate), displayedComponents: .date)
                .disabled(model.isRunning)
            DatePicker("Termina", selection: localDate($model.draft.endDate),
                       in: model.minimumEndDate.asDate..., displayedComponents: .date)
            Text("Del \(Formatting.longDay(model.draft.startDate)) al \(Formatting.longDay(model.draft.endDate)), ambos incluidos. La última noche termina a la mañana siguiente.")
                .foregroundStyle(Theme.ivorySecondary)
        }
        .datePickerStyle(.field)
    }

    private var lockStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(model.allowedLockKinds, id: \.self) { kind in
                lockOption(kind)
            }
            if model.confirmedFriends.isEmpty {
                Text("Para usar la llave de un amigo, regístralo antes en «Amigos».")
                    .font(.callout).foregroundStyle(Theme.ivoryTertiary)
            }
            if model.lockChoice == .password && (model.existing == nil || model.existing?.lock != .password) {
                SecureField("Contraseña (mínimo 4 caracteres)", text: $model.password)
                    .textFieldStyle(.roundedBorder)
            }
            if model.lockChoice != .noExit {
                Stepper(value: $model.draft.pauseMinutes, in: model.pauseRange) {
                    Text("Al desbloquear, pausa de \(model.draft.pauseMinutes) min")
                }
            }
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.draft.name).font(Theme.title(20))
            summaryLine("Bloquea", targetsSummary(model.draft.targets))
            summaryLine("Horario", Formatting.scheduleLabel(window: model.draft.window, weekdays: model.draft.weekdays))
            summaryLine("Fechas", "Del \(Formatting.longDay(model.draft.startDate)) al \(Formatting.longDay(model.draft.endDate))")
            summaryLine("Cerradura", lockDescription(model.lockChoice))
            if model.lockChoice == .noExit && model.existing?.lock != .noExit {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No podrás desbloquearlo antes del \(Formatting.longDay(model.draft.endDate)). Ni tú ni nadie.")
                        .foregroundStyle(Theme.gold)
                    TextField("Escribe «me comprometo»", text: $model.commitmentPhrase)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.gold.opacity(0.6)))
            }
            Text("Una vez empiece, solo podrás hacerlo más estricto.")
                .font(.callout).foregroundStyle(Theme.ivoryTertiary)
        }
    }

    // MARK: pieces

    private func lockOption(_ kind: LockKindChoice) -> some View {
        Button { model.lockChoice = kind } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.lockChoice == kind ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(model.lockChoice == kind ? Theme.gold : Theme.ivoryTertiary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(lockTitle(kind)).fontWeight(.semibold)
                    Text(lockDescription(kind)).font(.callout).foregroundStyle(Theme.ivorySecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func lockTitle(_ k: LockKindChoice) -> String {
        switch k {
        case .noExit: return "Sin salida"
        case .password: return "Contraseña"
        case .friend(let id): return "Llave de \(model.confirmedFriends.first { $0.id == id }?.name ?? "amigo")"
        }
    }

    private func lockDescription(_ k: LockKindChoice) -> String {
        switch k {
        case .noExit: return "Nada lo desbloquea hasta la fecha final."
        case .password: return "Tú eliges una contraseña. Desbloquear da una pausa."
        case .friend: return "Le llamas y te dicta el código de su móvil. Puede pausar o cancelar."
        }
    }

    private func summaryLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.ivoryTertiary).frame(width: 90, alignment: .leading)
            Text(value)
        }
    }

    private func chips(_ items: [String], canRemove: @escaping (String) -> Bool, remove: @escaping (String) -> Void) -> some View {
        FlowRow(items: items) { item in
            HStack(spacing: 4) {
                Text(item)
                if canRemove(item) {
                    Button { remove(item) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quitar \(item)")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Theme.nightHigh))
        }
    }

    private func timePicker(_ label: String, _ t: Binding<LocalTime>) -> some View {
        DatePicker(label, selection: Binding(
            get: { Calendar.current.date(from: DateComponents(hour: t.wrappedValue.hour, minute: t.wrappedValue.minute)) ?? .now },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); t.wrappedValue = LocalTime(c.hour ?? 0, c.minute ?? 0) }),
                   displayedComponents: .hourAndMinute)
            .datePickerStyle(.field)
    }

    private func localDate(_ d: Binding<LocalDate>) -> Binding<Date> {
        Binding(get: { d.wrappedValue.asDate }, set: { d.wrappedValue = LocalDate.containing($0, in: .current) })
    }

    private func addDomain() { domainError = model.addCustomDomain() }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Bloquear esta app"
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        model.draft.targets.apps.insert(AppTarget(bundleID: id, name: name, path: url.path))
    }

    private func dayName(_ d: Weekday) -> String {
        ["", "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"][d.rawValue]
    }
}

extension LocalDate {
    var asDate: Date { instant(at: LocalTime(12, 0), in: .current) }
}

extension Formatting {
    static func longDay(_ d: LocalDate) -> String {
        let months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre",
                      "octubre", "noviembre", "diciembre"]
        return "\(d.day) de \(months[d.month - 1])"
    }
}

/// Wrapping row of chips.
struct FlowRow<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        FlowLayout(spacing: 6) { ForEach(items, id: \.self) { content($0) } }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 480
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: subviews.isEmpty ? 0 : y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
