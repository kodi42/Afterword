import SwiftUI

/// Temporary Phase 0 root — a themed placeholder that proves the design tokens
/// and app shell are wired. Phase C replaces this with the Library.
struct RootView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.bg.ignoresSafeArea()
                VStack(spacing: Theme.Space.sm) {
                    Text("Afterword")
                        .font(Theme.Font.display)
                        .foregroundStyle(Theme.Palette.ink)
                    Text("Native rebuild — foundation in place")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkSoft)
                }
            }
        }
    }
}

#Preview {
    RootView()
}
