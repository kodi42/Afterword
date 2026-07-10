import Testing
import SwiftData
@testable import Afterword

/// Port of the surface-overlay cases from the RN `tests/queries.test.ts`
/// (alias chain-flatten, cycle guard, materialize + dedup).
@MainActor
struct SurfaceTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Book.self, ChapterNote.self, Character.self, Prediction.self, CharacterAlias.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func buildMapFlattensChain() {
        let map = AliasOperations.buildMap([
            CharacterAlias(alias: "a", canonical: "b"),
            CharacterAlias(alias: "b", canonical: "c"),
        ])
        #expect(map["a"] == "c")
        #expect(map["b"] == "c")
    }

    @Test func buildMapSurvivesCycle() {
        let map = AliasOperations.buildMap([
            CharacterAlias(alias: "a", canonical: "b"),
            CharacterAlias(alias: "b", canonical: "a"),
        ])
        #expect(map["a"] != nil)
    }

    @Test func mergeWritesNormalizedAliasAndReplaces() throws {
        let ctx = try makeContext()
        let book = Book(title: "T")
        ctx.insert(book)

        AliasOperations.merge("Ned", into: "Eddard Stark", book: book, in: ctx)
        try ctx.save()
        var rows = try ctx.fetch(FetchDescriptor<CharacterAlias>())
        #expect(rows.count == 1)
        #expect(rows.first?.alias == "ned")
        #expect(rows.first?.canonical == "eddard stark")

        // Re-merge replaces the target (update in place).
        AliasOperations.merge("Ned", into: "Lord Stark", book: book, in: ctx)
        try ctx.save()
        rows = try ctx.fetch(FetchDescriptor<CharacterAlias>())
        #expect(rows.count == 1)
        #expect(rows.first?.canonical == "lord stark")

        AliasOperations.unmerge("NED", book: book, in: ctx)
        try ctx.save()
        rows = try ctx.fetch(FetchDescriptor<CharacterAlias>())
        #expect(rows.isEmpty)
    }

    @Test func selfMergeIsIgnored() throws {
        let ctx = try makeContext()
        let book = Book(title: "T")
        ctx.insert(book)
        AliasOperations.merge("Ned", into: "ned", book: book, in: ctx)
        #expect(book.aliases.isEmpty)
    }

    @Test func answerSurfacedMaterializesAndDedupes() throws {
        let ctx = try makeContext()
        let book = Book(title: "T")
        ctx.insert(book)
        let surfaced = MarkerParser.SurfacedPrediction(id: 1, key: "winter is coming", chapter: 3, text: "Winter is coming")

        PredictionOperations.answerSurfaced(surfaced, wasCorrect: false, outcome: "it stayed summer", book: book, in: ctx)

        let stored = try ctx.fetch(FetchDescriptor<Prediction>())
        #expect(stored.count == 1)
        #expect(stored[0].prompt == "Winter is coming")
        #expect(stored[0].madeAtChapter == 3)
        #expect(stored[0].status == .answered)
        #expect(stored[0].wasCorrect == false)

        // Now deduped out of the surfaced view.
        #expect(PredictionOperations.storedKeys(stored).contains(surfaced.key))
    }
}
