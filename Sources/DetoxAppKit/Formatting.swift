import DetoxCore
import Foundation

public enum Formatting {
    /// "6 h 46 min", "45 min", "3 d 1 h", "menos de 1 min".
    public static func remaining(from: Date, to: Date) -> String {
        let minutes = Int(max(0, to.timeIntervalSince(from)) / 60)
        if minutes < 1 { return "menos de 1 min" }
        let d = minutes / 1440, h = (minutes % 1440) / 60, m = minutes % 60
        if d > 0 { return h > 0 ? "\(d) d \(h) h" : "\(d) d" }
        if h > 0 { return m > 0 ? "\(h) h \(m) min" : "\(h) h" }
        return "\(m) min"
    }

    public static func time(_ t: LocalTime) -> String { String(format: "%d:%02d", t.hour, t.minute) }

    public static func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return time(LocalTime(c.hour ?? 0, c.minute ?? 0))
    }

    static let weekdayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    static let letters: [Weekday: String] = [.monday: "L", .tuesday: "M", .wednesday: "X", .thursday: "J",
                                            .friday: "V", .saturday: "S", .sunday: "D"]

    public static func dayLetters(_ days: Set<Weekday>) -> String {
        weekdayOrder.filter(days.contains).compactMap { letters[$0] }.joined(separator: " ")
    }

    public static func scheduleLabel(window: DailyWindow, weekdays: Set<Weekday>) -> String {
        let all = weekdays.count == 7
        if window.isAllDay { return "Todo el día · " + (all ? "todos los días" : dayLetters(weekdays)) }
        let span = "\(time(window.start))–\(time(window.end))"
        if window.crossesMidnight {
            return span + (all ? " · todas las noches" : " · noches de " + dayLetters(weekdays))
        }
        return span + (all ? " · todos los días" : " · días " + dayLetters(weekdays))
    }

    public static func phaseLabel(_ p: BlockPhase) -> String {
        switch p {
        case .scheduled: return "Programado"
        case .running: return "En marcha"
        case .active: return "Activo"
        case .paused: return "En pausa"
        case .finished: return "Terminado"
        }
    }

    public static func lockLabel(_ l: LockSummary) -> String {
        switch l {
        case .noExit: return "Sin salida"
        case .password: return "Contraseña"
        case .friend(_, let name): return "Llave de \(name)"
        }
    }

    public static func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d 'de' MMMM, H:mm"
        return f.string(from: date)
    }

    public static func shortDate(_ d: LocalDate) -> String {
        let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        return "\(d.day) \(months[d.month - 1])"
    }

    public static func dateRange(_ a: LocalDate, _ b: LocalDate) -> String {
        "\(shortDate(a)) → \(shortDate(b))\(a.year != b.year ? " \(b.year)" : "")"
    }
}
