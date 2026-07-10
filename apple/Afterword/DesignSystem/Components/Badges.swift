import SwiftUI

/// A small status pill (active/gone, right/wrong, open, "from notes").
struct StatusBadge: View {
    enum Tone { case active, muted, correct, wrong }
    let text: String
    var tone: Tone = .active

    var body: some View {
        Text(text)
            .font(Theme.Font.caption).fontWeight(.semibold)
            .padding(.horizontal, Theme.Space.sm)
            .padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .active: return Theme.Palette.accent
        case .muted: return Theme.Palette.inkSoft
        case .correct: return Theme.Palette.success
        case .wrong: return Theme.Palette.danger
        }
    }
    private var background: Color {
        switch tone {
        case .active: return Theme.Palette.accentSoft
        case .muted: return Theme.Palette.surfaceAlt
        case .correct: return Color(hex: 0xDCEBE1)
        case .wrong: return Color(hex: 0xF3D9D8)
        }
    }
}

/// A tappable `ch. N` pill that jumps to a chapter note. Non-tappable when no
/// action is given.
struct ChapterTag: View {
    let chapter: Int
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            Text("ch. \(chapter)")
                .font(Theme.Font.caption).fontWeight(.semibold)
                .foregroundStyle(Theme.Palette.accent)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, 4)
                .background(Theme.Palette.surfaceAlt, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
