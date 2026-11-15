import DetoxCore
import SwiftUI

/// The signature: the night from 18:00 to 12:00 as one band, each block's window drawn on it,
/// a gold tick for "now". Day-only windows are clipped to the visible span.
public struct NightArc: View {
    public struct Band: Identifiable, Hashable {
        public var id: UUID
        public var window: DailyWindow
        public var isActive: Bool
    }

    let bands: [Band]
    let now: Date
    var compact = false

    public init(bands: [Band], now: Date, compact: Bool = false) {
        self.bands = bands
        self.now = now
        self.compact = compact
    }

    static let spanStart = 18 * 60         // 18:00
    static let spanLength = 18 * 60        // until 12:00 next day

    /// Minutes since 18:00 for a time of day, wrapping past midnight.
    static func offset(_ minutes: Int) -> Int { (minutes - spanStart + 1440) % 1440 }

    static func fraction(_ minutes: Int) -> CGFloat {
        CGFloat(min(offset(minutes), spanLength)) / CGFloat(spanLength)
    }

    static func range(_ w: DailyWindow) -> ClosedRange<CGFloat>? {
        if w.isAllDay { return 0...1 }
        let s = offset(w.start.minutesSinceMidnight)
        var e = offset(w.end.minutesSinceMidnight)
        if e <= s { e += 1440 }
        let lo = CGFloat(min(s, spanLength)) / CGFloat(spanLength)
        let hi = CGFloat(min(e, spanLength)) / CGFloat(spanLength)
        return hi > lo ? lo...hi : nil
    }

    private var nowMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var nowVisible: Bool { Self.offset(nowMinutes) <= Self.spanLength }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .leading) {
                    // Dusk → midnight → dawn: the night deepens toward 3:00 and lifts after.
                    Capsule()
                        .fill(LinearGradient(stops: [
                            .init(color: Theme.nightHigh, location: 0),
                            .init(color: Theme.night, location: 0.5),
                            .init(color: Theme.nightHigh, location: 0.8),
                            .init(color: Theme.nightRaised, location: 1),
                        ], startPoint: .leading, endPoint: .trailing))
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    ForEach(bands) { band in
                        if let r = Self.range(band.window) {
                            RoundedRectangle(cornerRadius: h / 2)
                                .fill(Theme.gold.opacity(band.isActive ? 0.28 : 0.12))
                                .overlay(RoundedRectangle(cornerRadius: h / 2)
                                    .strokeBorder(Theme.gold.opacity(band.isActive ? 0.9 : 0.4), lineWidth: 1))
                                .frame(width: max(h, (r.upperBound - r.lowerBound) * w))
                                .offset(x: r.lowerBound * w)
                        }
                    }
                    if nowVisible {
                        let x = Self.fraction(nowMinutes) * w
                        Rectangle().fill(Theme.gold).frame(width: 2, height: h + 8).offset(x: x - 1)
                    }
                }
            }
            .frame(height: compact ? 10 : 16)
            if !compact {
                HStack {
                    ForEach(["18:00", "21:00", "0:00", "3:00", "6:00", "9:00", "12:00"], id: \.self) { label in
                        Text(label)
                        if label != "12:00" { Spacer(minLength: 0) }
                    }
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.ivoryTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let parts = bands.map { "\(Formatting.time($0.window.start)) a \(Formatting.time($0.window.end))\($0.isActive ? ", activo" : "")" }
        return parts.isEmpty ? "Ninguna franja" : "Franjas: " + parts.joined(separator: "; ")
    }
}

extension NightArc.Band {
    public init(_ v: BlockView) {
        self.init(id: v.id, window: v.window, isActive: v.phase == .active)
    }
}
