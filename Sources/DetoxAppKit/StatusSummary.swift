import DetoxCore
import Foundation

/// The one line that names the span you are inside (header of every surface).
public enum StatusSummary {
    public static func headline(_ s: StatusSnapshot?) -> String {
        guard let s else { return "Conectando…" }
        let active = s.blocks.filter { $0.phase == .active }
        if let end = active.compactMap(\.activeWindowEnd).max() {
            return "Gran silencio hasta las \(Formatting.clock(end))"
        }
        if let paused = s.blocks.first(where: { $0.phase == .paused }), let until = paused.pausedUntil {
            return "En pausa hasta las \(Formatting.clock(until))"
        }
        if let next = s.blocks.compactMap(\.nextWindowStart).min() {
            let sameDay = Calendar.current.isDate(next, inSameDayAs: s.now)
            return sameDay ? "Esta noche, desde las \(Formatting.clock(next))"
                           : "Próximo silencio: \(Formatting.longDate(next))"
        }
        return "Sin bloqueos programados"
    }

    public static func detail(_ s: StatusSnapshot?) -> String? {
        guard let s else { return nil }
        if let end = s.blocks.filter({ $0.phase == .active }).compactMap(\.activeWindowEnd).max() {
            return "Faltan \(Formatting.remaining(from: s.now, to: end))"
        }
        if let next = s.blocks.compactMap(\.nextWindowStart).min() {
            return "Empieza en \(Formatting.remaining(from: s.now, to: next))"
        }
        return nil
    }
}
