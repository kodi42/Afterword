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

    /// Delete a book (children cascade) and tidy up its stored cover file.
    static func delete(_ book: Book, in context: ModelContext) {
        let coverName = book.coverLocalPath
        context.delete(book)
        CoverStore.delete(name: coverName)
    }
}
