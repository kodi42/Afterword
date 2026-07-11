import Testing
import Foundation
import SwiftData
@testable import Afterword

/// v1 feature additions: chapter-range notes and the Recently Deleted trash.
@MainActor
struct FeatureV1Tests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Book.self, ChapterNote.self, Character.self, Prediction.self, CharacterAlias.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: Range notes

    @Test func rangeNoteAdvancesToEndChapter() throws {
        let ctx = try makeContext()
        let book = Book(title: "Test")
        ctx.insert(book)

        let note = ChapterOperations.addNote(to: book, chapterNumber: 5, endChapter: 8, title: nil, body: "", in: ctx)
        #expect(note.chapterNumber == 5)
        #expect(note.endChapter == 8)
        #expect(book.currentChapter == 8) // progress reaches the far end of the range
    }

    @Test func rangeNoteNeverRewindsProgress() throws {
        let ctx = try makeContext()
        let book = Book(title: "Test")
        ctx.insert(book)

        ChapterOperations.addNote(to: book, chapterNumber: 10, title: nil, body: "", in: ctx)
        #expect(book.currentChapter == 10)

        // A later-logged earlier range must not pull progress backward.
        ChapterOperations.addNote(to: book, chapterNumber: 2, endChapter: 4, title: nil, body: "", in: ctx)
        #expect(book.currentChapter == 10)
    }

    @Test func singleChapterNoteStillWorks() throws {
        let ctx = try makeContext()
        let book = Book(title: "Test")
        ctx.insert(book)

        let note = ChapterOperations.addNote(to: book, chapterNumber: 3, title: nil, body: "", in: ctx)
        #expect(note.endChapter == nil)
        #expect(book.currentChapter == 3)
    }

    // MARK: Recently Deleted

    @Test func softDeleteAndRestore() throws {
        let ctx = try makeContext()
        let book = Book(title: "Test")
        ctx.insert(book)

        BookOperations.softDelete(book)
        #expect(book.deletedAt != nil)
        // Still present in the store — just hidden from the shelves.
        #expect(try ctx.fetch(FetchDescriptor<Book>()).count == 1)

        BookOperations.restore(book)
        #expect(book.deletedAt == nil)
    }

    @Test func purgeRemovesExpiredKeepsRecentAndLive() throws {
        let ctx = try makeContext()

        let live = Book(title: "Live")
        let recentlyDeleted = Book(title: "Recent")
        let expired = Book(title: "Expired")
        [live, recentlyDeleted, expired].forEach(ctx.insert)

        BookOperations.softDelete(recentlyDeleted)          // deleted just now
        expired.deletedAt = Date(timeIntervalSince1970: 0)  // deleted long ago
        try ctx.save()

        BookOperations.purgeExpired(in: ctx)

        let remaining = try ctx.fetch(FetchDescriptor<Book>()).map(\.title).sorted()
        #expect(remaining == ["Live", "Recent"]) // only the week-old trash is gone
    }

    @Test func purgeCascadesToChildren() throws {
        let ctx = try makeContext()
        let book = Book(title: "Expired")
        ctx.insert(book)
        ChapterOperations.addNote(to: book, chapterNumber: 1, title: nil, body: "hi", in: ctx)
        book.deletedAt = Date(timeIntervalSince1970: 0)
        try ctx.save()

        BookOperations.purgeExpired(in: ctx)

        #expect(try ctx.fetch(FetchDescriptor<Book>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<ChapterNote>()).isEmpty)
    }
}
