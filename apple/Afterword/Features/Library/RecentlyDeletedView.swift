import SwiftUI
import SwiftData

/// The trash. Books soft-deleted from the shelf land here and are purged for good
/// 7 days after deletion (see `BookOperations.purgeExpired`). Swipe to restore a
/// book or delete it immediately. Reached from the Library's "…" menu.
struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]

    private var trashed: [Book] { books.filter { $0.deletedAt != nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.bg.ignoresSafeArea()
                if trashed.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing here", systemImage: "trash")
                    } description: {
                        Text("Books you delete show up here for 7 days, then they're gone for good.")
                    }
                } else {
                    List {
                        Section {
                            ForEach(trashed) { book in row(book) }
                        } footer: {
                            Text("Books are permanently deleted 7 days after you remove them.")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.inkSoft)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Theme.Palette.accent)
    }

    private func row(_ book: Book) -> some View {
        HStack(spacing: Theme.Space.md) {
            BookCover(coverName: book.coverLocalPath, width: 44)
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
                if let deletedAt = book.deletedAt {
                    Text(daysLeftText(deletedAt))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.inkFaint)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .plainListRow()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                BookOperations.permanentlyDelete(book, in: context)
            } label: {
                Label("Delete Now", systemImage: "trash")
            }
            Button {
                BookOperations.restore(book)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(Theme.Palette.accent)
        }
    }

    /// "6 days left" — how long until this book is purged for good.
    private func daysLeftText(_ deletedAt: Date) -> String {
        let purgeDate = deletedAt.addingTimeInterval(BookOperations.trashRetention)
        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: purgeDate).day ?? 0)
        switch days {
        case 0: return "Deletes today"
        case 1: return "1 day left"
        default: return "\(days) days left"
        }
    }
}
