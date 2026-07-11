import SwiftUI

/// One book on the Library shelf: cover, title, author, reading progress.
struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            BookCover(coverName: book.coverLocalPath, width: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(1)
                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .lineLimit(1)
                }
                BookProgressView(book: book)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }
}
