import SwiftUI
import UIKit

/// A book's cover thumbnail, or a paper-toned placeholder. Fixed 2:3 portrait
/// ratio so rows and headers line up. Loads a local file by stored filename.
struct BookCover: View {
    var coverName: String?
    var width: CGFloat = 44

    private var height: CGFloat { (width * 1.5).rounded() }

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
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
                    .font(.system(size: width * 0.42))
                    .foregroundStyle(Theme.Palette.inkFaint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}
