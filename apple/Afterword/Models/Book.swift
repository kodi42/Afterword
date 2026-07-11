import Foundation
import SwiftData

enum BookStatus: String, Codable, CaseIterable {
    case reading, finished
}

/// The shelf. Everything hangs off a book, and deleting a book cascades to all
/// its children — the native equivalent of the RN schema's `onDelete: 'cascade'`.
@Model
final class Book {
    var title: String
    var author: String?
    var status: BookStatus
    var coverLocalPath: String?     // local file path (was coverUri)
    var totalChapters: Int?
    var currentChapter: Int?
    var startedAt: Date?
    var finishedAt: Date?
    /// When soft-deleted (moved to Recently Deleted). Nil = live on the shelf.
    /// Purged for good 7 days later — see `BookOperations.purgeExpired`.
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChapterNote.book)
    var chapterNotes: [ChapterNote] = []

    @Relationship(deleteRule: .cascade, inverse: \Character.book)
    var characters: [Character] = []

    @Relationship(deleteRule: .cascade, inverse: \Prediction.book)
    var predictions: [Prediction] = []

    @Relationship(deleteRule: .cascade, inverse: \CharacterAlias.book)
    var aliases: [CharacterAlias] = []

    init(
        title: String,
        author: String? = nil,
        totalChapters: Int? = nil,
        status: BookStatus = .reading,
        startedAt: Date? = nil
    ) {
        self.title = title
        self.author = author
        self.status = status
        self.totalChapters = totalChapters
        self.startedAt = startedAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
