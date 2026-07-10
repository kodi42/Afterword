import Foundation
import SwiftData

/// Chapter-note writes. Screens call these instead of mutating the store inline —
/// the native echo of the RN "writes go through features" convention.
enum ChapterOperations {
    /// Insert a note and advance the book's progress to that chapter — forward
    /// only. Logging an earlier chapter never rewinds `currentChapter`, matching
    /// the RN `addChapterNote` / `advanceCurrentChapter` behavior.
    @discardableResult
    static func addNote(
        to book: Book,
        chapterNumber: Int,
        title: String?,
        body: String,
        in context: ModelContext
    ) -> ChapterNote {
        let note = ChapterNote(chapterNumber: chapterNumber, title: title, body: body, book: book)
        context.insert(note)

        if let current = book.currentChapter {
            if chapterNumber > current { book.currentChapter = chapterNumber }
        } else {
            book.currentChapter = chapterNumber
        }
        book.updatedAt = Date()
        return note
    }

    /// Edit an existing note. Never touches `currentChapter` — editing an old
    /// note's chapter shouldn't move where the reader currently is.
    static func update(
        _ note: ChapterNote,
        chapterNumber: Int,
        title: String?,
        body: String
    ) {
        note.chapterNumber = chapterNumber
        note.title = title
        note.body = body
        note.updatedAt = Date()
    }
}
