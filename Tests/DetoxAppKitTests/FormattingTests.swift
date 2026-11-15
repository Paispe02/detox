import DetoxCore
import Foundation
import Testing
@testable import DetoxAppKit

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Test func remainingText() {
    #expect(Formatting.remaining(from: t0, to: t0 + 6 * 3600 + 46 * 60) == "6 h 46 min")
    #expect(Formatting.remaining(from: t0, to: t0 + 7 * 3600) == "7 h")
    #expect(Formatting.remaining(from: t0, to: t0 + 45 * 60) == "45 min")
    #expect(Formatting.remaining(from: t0, to: t0 + 30) == "menos de 1 min")
    #expect(Formatting.remaining(from: t0, to: t0 + 3 * 86400 + 3600) == "3 d 1 h")
}

private let night = DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0))

@Test func scheduleLabels() {
    #expect(Formatting.scheduleLabel(window: night, weekdays: Set(Weekday.allCases)) == "22:30–6:00 · todas las noches")
    #expect(Formatting.scheduleLabel(window: night, weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday])
            == "22:30–6:00 · noches de L M X J V")
    #expect(Formatting.scheduleLabel(window: DailyWindow(start: LocalTime(9, 0), end: LocalTime(14, 0)),
                                     weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday])
            == "9:00–14:00 · días L M X J V")
    #expect(Formatting.scheduleLabel(window: DailyWindow(start: LocalTime(9, 0), end: LocalTime(14, 0)),
                                     weekdays: Set(Weekday.allCases)) == "9:00–14:00 · todos los días")
    #expect(Formatting.scheduleLabel(window: DailyWindow(start: LocalTime(0, 0), end: LocalTime(0, 0)),
                                     weekdays: [.saturday, .sunday]) == "Todo el día · S D")
}

@Test func phaseAndLockLabels() {
    #expect([BlockPhase.scheduled, .running, .active, .paused, .finished].map(Formatting.phaseLabel)
            == ["Programado", "En marcha", "Activo", "En pausa", "Terminado"])
    #expect(Formatting.lockLabel(.noExit) == "Sin salida")
    #expect(Formatting.lockLabel(.password) == "Contraseña")
    #expect(Formatting.lockLabel(.friend(id: UUID(), name: "Ana")) == "Llave de Ana")
}

@Test func errorMessages() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    let at = cal.date(from: DateComponents(year: 2026, month: 12, day: 3, hour: 23, minute: 40))!
    #expect(CommandError.wrongCredential.userMessage == "Contraseña o código incorrecto.")
    #expect(CommandError.rateLimited(until: at).userMessage == "Demasiados intentos. Vuelve a intentarlo a las 23:40.")
    #expect(CommandError.noExit(endsAt: at).userMessage == "Este bloqueo no tiene salida hasta el 3 de diciembre, 23:40.")
    #expect(CommandError.tightening([.removesTargets]).userMessage == "Un bloqueo en marcha solo puede endurecerse.")
    #expect(CommandError.friendInUse.userMessage == "Este amigo tiene la llave de un bloqueo en marcha.")
    #expect(CommandError.daemonUnavailable.userMessage == "El servicio de Detox está desactivado.")
    #expect(CommandError.invalid("fechas").userMessage.contains("fecha"))
}
