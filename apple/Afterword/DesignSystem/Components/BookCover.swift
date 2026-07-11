import SwiftUI
import UIKit

/// A book's cover thumbnail, or a paper-toned placeholder. Fixed 2:3 portrait
/// ratio so rows and headers line up. Loads a local file by stored filename.
struct BookCover: View {
    var coverName: String?
    /// A fixed width (rows, headers, form preview). When `nil` the cover fills
    /// its container's width at the 2:3 ratio — used by the Library cover grid.
    var width: CGFloat? = 44

    private var height: CGFloat? { width.map { ($0 * 1.5).rounded() } }

    var body: some View {
        sized
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    @ViewBuilder private var sized: some View {
        if let width {
            artwork.frame(width: width, height: height)
        } else {
            // Fill the available width, keep the 2:3 ratio (grid cells).
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay { artwork }
                .clipped()
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = loadImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private func loadImage() -> UIImage? {
        guard let url = CoverStore.fileURL(for: coverName) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .fill(Theme.Palette.surfaceAlt)
            .overlay(
                Image(systemName: "book.closed")
                    .font(.system(size: (width ?? 96) * 0.42))
                    .foregroundStyle(Theme.Palette.inkFaint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}
