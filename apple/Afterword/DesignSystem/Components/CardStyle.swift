import SwiftUI

/// The card surface used throughout — white fill, hairline border, large radius.
/// Mirrors the RN `Card` component.
struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.Space.md
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = Theme.Space.md) -> some View {
        modifier(CardModifier(padding: padding))
    }
}
