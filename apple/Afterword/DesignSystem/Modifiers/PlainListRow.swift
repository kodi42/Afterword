import SwiftUI

/// A List row styled to sit on the paper background as a free-floating card:
/// clear background, no separators, horizontal padding matching the screen.
struct PlainListRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.Space.xs, leading: Theme.Space.md,
                                      bottom: Theme.Space.xs, trailing: Theme.Space.md))
    }
}

extension View {
    func plainListRow() -> some View { modifier(PlainListRow()) }
}
