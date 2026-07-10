import SwiftUI
import UIKit

/// Design tokens ported from the RN app's `src/theme/tokens.ts` — the warm
/// "paper and ink" identity, now light/dark adaptive. Spacing/radius/type match
/// the RN scale 1:1 so the port stays visually honest.
enum Theme {
    enum Palette {
        static let bg = Color(light: 0xF6F1E7, dark: 0x17140F)          // warm paper / ink night
        static let surface = Color(light: 0xFFFFFF, dark: 0x231E17)      // cards
        static let surfaceAlt = Color(light: 0xEFE7D6, dark: 0x322B20)   // subtle fills
        static let ink = Color(light: 0x26221C, dark: 0xEDE7DA)          // primary text
        static let inkSoft = Color(light: 0x6B6357, dark: 0xB3A996)      // secondary text
        static let inkFaint = Color(light: 0xA79E8C, dark: 0x7C7362)     // hints, placeholders
        static let accent = Color(light: 0xB4562B, dark: 0xD07A4E)       // terracotta
        static let accentSoft = Color(light: 0xF0DDCF, dark: 0x40291D)
        static let border = Color(light: 0xE3DACA, dark: 0x3A3227)
        static let success = Color(light: 0x3F7A55, dark: 0x74B78C)
        static let danger = Color(light: 0xB23A38, dark: 0xDD6763)
        static let badgeCorrect = Color(light: 0xDCEBE1, dark: 0x24382B)
        static let badgeWrong = Color(light: 0xF3D9D8, dark: 0x3E2523)
    }

    /// 8pt-ish spacing scale (matches RN spacing tokens).
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let pill: CGFloat = 999
    }

    /// Typography. Display leans on a serif for the reading identity; the rest
    /// use the system font. All relative so Dynamic Type scales them.
    enum Font {
        static let display = SwiftUI.Font.system(.largeTitle, design: .serif).weight(.bold)
        static let title = SwiftUI.Font.system(.title2, design: .serif).weight(.bold)
        static let heading = SwiftUI.Font.system(.headline)
        static let body = SwiftUI.Font.system(.body)
        static let label = SwiftUI.Font.system(.subheadline).weight(.semibold)
        static let caption = SwiftUI.Font.system(.footnote)
    }
}

extension Color {
    /// Build a Color from a 0xRRGGBB literal.
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// An adaptive color that resolves to `light` or `dark` per the trait environment.
    init(light: UInt, dark: UInt) {
        self = Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}
