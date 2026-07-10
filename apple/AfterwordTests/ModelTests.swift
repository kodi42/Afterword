import Testing
import SwiftData
@testable import Afterword

/// Phase A: the data layer, mirroring the RN `tests/queries.test.ts` cases against
/// an in-memory SwiftData store.
@MainActor
struct ModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Book.self, ChapterNote.self, Character.self, Prediction.self, CharacterAlias.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func createAndReadBook() throws {
        let ctx = try makeContext()
        ctx.insert(Book(title: "Test Book"))
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Book>())
        #expect(all.count == 1)
        #expect(all.first?.title == "Test Book")
        #expect(all.first?.status == .reading)
    }

    @Test func cascadeDeleteRemovesChildren() throws {
        let ctx = try makeContext()
        let book = Book(title: "Test")
        ctx.insert(book)
        ChapterOperations.addNote(to: book, chapterNumber: 1, title: nil, body: "hi", in: ctx)
        ctx.insert(Character(name: "Ned", book: book))
        ctx.insert(Prediction(prompt: "guess", book: book))
        try ctx.save()

        ctx.delete(book)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<ChapterNote>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Character>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Prediction>()).isEmpty)
    }

    @Test func addNoteAdvancesForwardOnly() throws {
        let ctx = try makeContext()
        let book = Book(title: "Test")
        ctx.insert(book)

        ChapterOperations.addNote(to: book, chapterNumber: 5, title: nil, body: "", in: ctx)
        #expect(book.currentChapter == 5)

        ChapterOperations.addNote(to: book, chapterNumber: 2, title: nil, body: "", in: ctx)
        #expect(book.currentChapter == 5) // never rewinds
    }

    @Test func answerAndReopenPrediction() throws {
        let ctx = try makeContext()
        let book = Book(title: "Test")
        ctx.insert(book)
        let p = Prediction(prompt: "The butler did it", book: book)
        ctx.insert(p)

        PredictionOperations.answer(p, wasCorrect: true, outcome: "  it was the butler  ")
        #expect(p.status == .answered)
        #expect(p.wasCorrect == true)
        #expect(p.outcome == "it was the butler") // trimmed

        PredictionOperations.reopen(p)
        #expect(p.status == .open)
        #expect(p.wasCorrect == nil)
        #expect(p.outcome == nil)
    }
}
