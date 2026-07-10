import Testing
import Foundation
import SwiftData
@testable import Afterword

/// Verifies the Expo → native import: JSON parses, rows land in SwiftData, and
/// highlights regenerate from imported note bodies via MarkerParser.
@MainActor
struct ImportTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Book.self, ChapterNote.self, Character.self, Prediction.self, CharacterAlias.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private let sample = Data(#"""
    {
      "version": 1,
      "books": [
        {
          "title": "A Game of Thrones",
          "author": "George R. R. Martin",
          "status": "reading",
          "totalChapters": 73,
          "currentChapter": 12,
          "chapterNotes": [
            { "chapterNumber": 1, "title": "Bran", "body": "- Ned: Warden of the North\n* The direwolves are found\n? Bran will climb again" }
          ],
          "characters": [
            { "name": "Eddard Stark", "description": "Lord of Winterfell", "firstSeenChapter": 1, "status": "active" }
          ],
          "predictions": [
            { "prompt": "Ned loses his head", "madeAtChapter": 5, "status": "answered", "outcome": "he did", "wasCorrect": true }
          ],
          "aliases": [ { "alias": "ned", "canonical": "eddard stark" } ]
        }
      ]
    }
    """#.utf8)

    @Test func importsBooksAndChildren() throws {
        let ctx = try makeContext()
        let summary = try ImportService.importData(sample, into: ctx)

        #expect(summary.books == 1)
        #expect(summary.notes == 1)
        #expect(summary.characters == 1)
        #expect(summary.predictions == 1)

        let books = try ctx.fetch(FetchDescriptor<Book>())
        #expect(books.count == 1)
        let book = books[0]
        #expect(book.title == "A Game of Thrones")
        #expect(book.currentChapter == 12)
        #expect(book.chapterNotes.count == 1)
        #expect(book.characters.first?.detail == "Lord of Winterfell")
        #expect(book.predictions.first?.wasCorrect == true)
        #expect(book.aliases.first?.canonical == "eddard stark")
    }

    @Test func highlightsRegenerateFromImportedNotes() throws {
        let ctx = try makeContext()
        try ImportService.importData(sample, into: ctx)
        let book = try ctx.fetch(FetchDescriptor<Book>())[0]

        let parsed = MarkerParser.parse(
            book.chapterNotes.map { .init(chapterNumber: $0.chapterNumber, body: $0.body) }
        )
        #expect(parsed.highlights.map(\.text) == ["The direwolves are found"])
        #expect(parsed.characters.contains { $0.name == "Ned" })
        #expect(parsed.predictions.contains { $0.text == "Bran will climb again" })
    }

    @Test func rejectsUnknownJSON() throws {
        let ctx = try makeContext()
        #expect(throws: ImportService.ImportError.self) {
            try ImportService.importData(Data(#"{"nope":true}"#.utf8), into: ctx)
        }
    }
}
