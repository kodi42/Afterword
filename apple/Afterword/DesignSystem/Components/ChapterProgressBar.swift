import SwiftUI

/// A thin reading-progress bar — terracotta fill over a faint track with a small
/// "current / total" caption. Shown in place of the "Ch X of Y" label when the
/// reader turns on the progress-bar preference in Settings.
struct ChapterProgressBar: View {
    let current: Int
    let total: Int

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(current) / Double(total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.surfaceAlt)
                    Capsule()
                        .fill(Theme.Palette.accent)
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 5)
            Text("\(current) / \(total)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.inkSoft)
        }
    }
}
