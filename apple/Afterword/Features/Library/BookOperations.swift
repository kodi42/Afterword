import Foundation
import SwiftData

/// Book writes. Mirrors the RN `src/features/books/queries.ts`.
enum BookOperations {
    @discardableResult
    static func create(
        title: String,
        author: String?,
        totalChapters: Int?,
        coverName: String?,
        in context: ModelContext
    ) -> Book {
        let book = Book(title: title, author: author, totalChapters: totalChapters, status: .reading, startedAt: Date())
        book.coverLocalPath = coverName
        context.insert(book)
        return book
    }

    static func update(
        _ book: Book,
        title: String,
        author: String?,
        totalChapters: Int?,
        coverName: String?
    ) {
        book.title = title
        book.author = author
        book.totalChapters = totalChapters
        book.coverLocalPath = coverName
        book.updatedAt = Date()
    }

    static func markFinished(_ book: Book) {
        book.status = .finished
        book.finishedAt = Date()
        book.updatedAt = Date()
    }

    /// Undo "finished" — put a book back on the reading shelf.
    static func markReading(_ book: Book) {
        book.status = .reading
        book.finishedAt = nil
        book.updatedAt = Date()
    }

    /// How long a soft-deleted book lingers in Recently Deleted before it's
    /// purged for good.
    static let trashRetention: TimeInterval = 7 * 24 * 60 * 60

    /// Soft-delete: move a book to Recently Deleted. Children stay attached so a
    /// restore brings everything back; the cover file is kept until purge.
    static func softDelete(_ book: Book) {
        book.deletedAt = Date()
        book.updatedAt = Date()
    }

    /// Undo a soft-delete — put the book back on its shelf.
    static func restore(_ book: Book) {
        book.deletedAt = nil
        book.updatedAt = Date()
    }

    /// Permanently delete a book (children cascade) and tidy up its cover file.
    static func permanentlyDelete(_ book: Book, in context: ModelContext) {
        let coverName = book.coverLocalPath
        context.delete(book)
        CoverStore.delete(name: coverName)
    }

    /// Purge books trashed more than `trashRetention` ago. Called on launch.
    /// `now` is injectable so tests can back-date without waiting a week.
    static func purgeExpired(in context: ModelContext, now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-trashRetention)
        guard let all = try? context.fetch(FetchDescriptor<Book>()) else { return }
        for book in all {
            if let deletedAt = book.deletedAt, deletedAt < cutoff {
                permanentlyDelete(book, in: context)
            }
        }
    }
}
