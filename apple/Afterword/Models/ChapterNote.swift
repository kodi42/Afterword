import Foundation
import SwiftData

/// The core feature: one reflection per chapter. Marker lines inside `body`
/// (`- Name: desc`, `* ...`, `? ...`) are what the surface parser reads later.
@Model
final class ChapterNote {
    var chapterNumber: Int
    /// Optional end of a chapter range — a note covering chapters 5–8 has
    /// `chapterNumber == 5`, `endChapter == 8`. Nil means a single-chapter note.
    var endChapter: Int?
    var title: String?
    var body: String
    var createdAt: Date
    var updatedAt: Date

    var book: Book?

    init(chapterNumber: Int, endChapter: Int? = nil, title: String? = nil, body: String = "", book: Book? = nil) {
        self.chapterNumber = chapterNumber
        self.endChapter = endChapter
        self.title = title
        self.body = body
        self.book = book
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
