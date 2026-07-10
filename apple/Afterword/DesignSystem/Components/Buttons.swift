import SwiftUI

/// Full-width action button. `.primary` is the terracotta fill, `.ghost` is a
/// bordered secondary — mirrors the RN `Button` variants.
struct AfterwordButtonStyle: ButtonStyle {
    enum Kind { case primary, ghost }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.label)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(kind == .primary ? Color.white : Theme.Palette.ink)
            .background(kind == .primary ? Theme.Palette.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay {
                if kind == .ghost {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.Palette.border, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AfterwordButtonStyle {
    static var afterwordPrimary: AfterwordButtonStyle { AfterwordButtonStyle(kind: .primary) }
    static var afterwordGhost: AfterwordButtonStyle { AfterwordButtonStyle(kind: .ghost) }
}
