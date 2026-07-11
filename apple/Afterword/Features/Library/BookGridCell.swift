import SwiftUI

/// One book as a cover-forward grid cell: the full-width cover with title, author
/// and progress stacked underneath. The list counterpart is `BookRow`.
struct BookGridCell: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            BookCover(coverName: book.coverLocalPath, width: nil)
            Text(book.title)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)
            if let author = book.author, !author.isEmpty {
                Text(author)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .lineLimit(1)
            }
            BookProgressView(book: book)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
