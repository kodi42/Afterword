import Foundation
import SwiftData

/// The core feature: one reflection per chapter. Marker lines inside `body`
/// (`- Name: desc`, `* ...`, `? ...`) are what the surface parser reads later.
@Model
final class ChapterNote {
    var chapterNumber: Int
    var title: String?
    var body: String
    var createdAt: Date
    var updatedAt: Date

    var book: Book?

    init(chapterNumber: Int, title: String? = nil, body: String = "", book: Book? = nil) {
        self.chapterNumber = chapterNumber
        self.title = title
        self.body = body
        self.book = book
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
