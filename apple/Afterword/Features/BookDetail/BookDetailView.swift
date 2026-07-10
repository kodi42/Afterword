import SwiftUI

/// Phase C stub — proves Library navigation. Phase D fills in the header (cover,
/// actions menu) and the Chapters / Reference tabs.
struct BookDetailView: View {
    @Bindable var book: Book

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Space.sm) {
                BookCover(coverName: book.coverLocalPath, width: 96)
                Text(book.title).font(Theme.Font.display).foregroundStyle(Theme.Palette.ink)
                if let author = book.author { Text(author).font(Theme.Font.body).foregroundStyle(Theme.Palette.inkSoft) }
            }
            .padding()
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
