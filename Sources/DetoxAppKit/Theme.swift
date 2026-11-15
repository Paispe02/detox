import SwiftUI

/// Brand palette (Guía de marca · Alejandro Pais) applied to a night-time tool.
public enum Theme {
    public static let night = Color(red: 5 / 255, green: 21 / 255, blue: 38 / 255)          // #051526
    public static let nightRaised = Color(red: 11 / 255, green: 34 / 255, blue: 56 / 255)    // #0B2238
    public static let nightHigh = Color(red: 18 / 255, green: 48 / 255, blue: 77 / 255)      // #12304D
    public static let ivory = Color(red: 247 / 255, green: 244 / 255, blue: 236 / 255)       // #F7F4EC
    public static let gold = Color(red: 207 / 255, green: 160 / 255, blue: 70 / 255)         // #CFA046

    public static let ivorySecondary = ivory.opacity(0.72)
    public static let ivoryTertiary = ivory.opacity(0.5)
    public static let hairline = ivory.opacity(0.12)

    public static func title(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
    public static func titleBold(_ size: CGFloat) -> Font { .custom("Georgia-Bold", size: size) }
}

extension View {
    /// Night ground for every Detox surface: it is used in the dark.
    public func nightSurface() -> some View {
        self.foregroundStyle(Theme.ivory)
            .tint(Theme.gold)
            .background(Theme.night)
            .preferredColorScheme(.dark)
    }
}
