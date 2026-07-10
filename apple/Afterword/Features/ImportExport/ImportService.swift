import Foundation
import SwiftData

/// Imports an Afterword export file (produced by the Expo app's Export action,
/// schema `version: 1`) into the SwiftData store. Books and their children are
/// recreated; highlights need no special handling — they regenerate from the
/// imported note bodies via `MarkerParser`. Covers don't travel (local files).
enum ImportService {
    struct ImportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct Summary {
        var books = 0
        var notes = 0
        var characters = 0
        var predictions = 0
    }

    // MARK: - Wire format (matches src/features/export/exportData.ts)

    private struct Payload: Decodable {
        let version: Int
        let books: [BookDTO]
    }
    private struct BookDTO: Decodable {
        let title: String
        let author: String?
        let status: String?
        let totalChapters: Int?
        let currentChapter: Int?
        let startedAt: Double?
        let finishedAt: Double?
        let chapterNotes: [NoteDTO]?
        let characters: [CharacterDTO]?
        let predictions: [PredictionDTO]?
        let aliases: [AliasDTO]?
    }
    private struct NoteDTO: Decodable {
        let chapterNumber: Int
        let title: String?
        let body: String?
        let createdAt: Double?
    }
    private struct CharacterDTO: Decodable {
        let name: String
        let description: String?
        let firstSeenChapter: Int?
        let status: String?
    }
    private struct PredictionDTO: Decodable {
        let prompt: String
        let madeAtChapter: Int?
        let status: String?
        let outcome: String?
        let wasCorrect: Bool?
    }
    private struct AliasDTO: Decodable {
        let alias: String
        let canonical: String
    }

    // MARK: - Import

    /// Parse a JSON file at `url` and insert its contents. Returns a count summary.
    @discardableResult
    static func importFile(at url: URL, into context: ModelContext) throws -> Summary {
        // Security-scoped access is needed for files handed over by the document picker.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ImportError(message: "Couldn't read that file.") }

        return try importData(data, into: context)
    }

    /// Parse JSON `data` and insert its contents. Returns a count summary.
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) throws -> Summary {
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) }
        catch { throw ImportError(message: "That doesn't look like an Afterword export.") }

        guard payload.version == 1 else {
            throw ImportError(message: "Unsupported export version (\(payload.version)).")
        }

        var summary = Summary()
        for dto in payload.books {
            let book = Book(
                title: dto.title,
                author: dto.author,
                totalChapters: dto.totalChapters,
                status: dto.status == "finished" ? .finished : .reading,
                startedAt: date(dto.startedAt)
            )
            book.currentChapter = dto.currentChapter
            book.finishedAt = date(dto.finishedAt)
            context.insert(book)
            summary.books += 1

            for n in dto.chapterNotes ?? [] {
                let note = ChapterNote(chapterNumber: n.chapterNumber, title: n.title, body: n.body ?? "", book: book)
                if let created = date(n.createdAt) { note.createdAt = created }
                context.insert(note)
                summary.notes += 1
            }
            for c in dto.characters ?? [] {
                context.insert(Character(name: c.name, detail: c.description, firstSeenChapter: c.firstSeenChapter,
                                         status: c.status == "gone" ? .gone : .active, book: book))
                summary.characters += 1
            }
            for p in dto.predictions ?? [] {
                let prediction = Prediction(prompt: p.prompt, madeAtChapter: p.madeAtChapter,
                                            status: p.status == "answered" ? .answered : .open, book: book)
                prediction.outcome = p.outcome
                prediction.wasCorrect = p.wasCorrect
                context.insert(prediction)
                summary.predictions += 1
            }
            for a in dto.aliases ?? [] {
                context.insert(CharacterAlias(alias: a.alias, canonical: a.canonical, book: book))
            }
        }

        try context.save()
        return summary
    }

    private static func date(_ millis: Double?) -> Date? {
        guard let millis else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }
}
