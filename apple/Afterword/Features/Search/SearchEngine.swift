import Foundation
import SwiftData

/// Global search across every book's chapter notes and reference entries. Port of
/// the RN `src/features/search/queries.ts`. Fetches then filters case-insensitively
/// in memory — plenty fast at a personal library's scale, and case/diacritic-
/// insensitive like the RN `LIKE`. (An FTS index is the future upgrade.)
enum SearchEngine {
    struct Results {
        var notes: [ChapterNote] = []
        var characters: [Character] = []
        var predictions: [Prediction] = []
        var isEmpty: Bool { notes.isEmpty && characters.isEmpty && predictions.isEmpty }
    }

    static func search(_ rawTerm: String, in context: ModelContext) -> Results {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return Results() }

        func has(_ value: String?) -> Bool { value?.localizedCaseInsensitiveContains(term) ?? false }

        let notes = (try? context.fetch(
            FetchDescriptor<ChapterNote>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )) ?? []
        let characters = (try? context.fetch(
            FetchDescriptor<Character>(sortBy: [SortDescriptor(\.name)])
        )) ?? []
        let predictions = (try? context.fetch(
            FetchDescriptor<Prediction>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )) ?? []

        return Results(
            notes: notes.filter { has($0.body) || has($0.title) },
            characters: characters.filter { has($0.name) || has($0.detail) },
            predictions: predictions.filter { has($0.prompt) || has($0.outcome) }
        )
    }
}
