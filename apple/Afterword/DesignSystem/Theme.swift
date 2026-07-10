import SwiftUI

/// Design tokens ported from the RN app's `src/theme/tokens.ts` — the warm
/// "paper and ink" identity. Colors are defined as light values here; Phase B
/// promotes them to an asset catalog with Dark Mode variants. Spacing/radius/type
/// match the RN scale 1:1 so the port stays visually honest.
enum Theme {
    enum Palette {
        static let bg = Color(hex: 0xF6F1E7)          // warm paper
        static let surface = Color(hex: 0xFFFFFF)      // cards
        static let surfaceAlt = Color(hex: 0xEFE7D6)   // subtle fills
        static let ink = Color(hex: 0x26221C)          // primary text
        static let inkSoft = Color(hex: 0x6B6357)      // secondary text
        static let inkFaint = Color(hex: 0xA79E8C)     // hints, placeholders
        static let accent = Color(hex: 0xB4562B)       // terracotta
        static let accentSoft = Color(hex: 0xF0DDCF)
        static let border = Color(hex: 0xE3DACA)
        static let success = Color(hex: 0x3F7A55)
        static let danger = Color(hex: 0xB23A38)
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
}
