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
        endChapter: Int? = nil,
        title: String?,
        body: String,
        in context: ModelContext
    ) -> ChapterNote {
        let note = ChapterNote(chapterNumber: chapterNumber, endChapter: endChapter, title: title, body: body)
        context.insert(note)
        // Wire the relationship from the PARENT side. Setting only `note.book`
        // persists fine but leaves the book's already-materialized
        // `chapterNotes` array stale, so the Chapters list doesn't refresh until
        // you leave the book and come back. Appending mutates the array in place
        // and triggers the SwiftUI update.
        book.chapterNotes.append(note)

        // A range note advances progress to the furthest chapter it covers.
        let reached = max(chapterNumber, endChapter ?? chapterNumber)
        if let current = book.currentChapter {
            if reached > current { book.currentChapter = reached }
        } else {
            book.currentChapter = reached
        }
        book.updatedAt = Date()
        return note
    }

    /// Edit an existing note. Never touches `currentChapter` — editing an old
    /// note's chapter shouldn't move where the reader currently is.
    static func update(
        _ note: ChapterNote,
        chapterNumber: Int,
        endChapter: Int?,
        title: String?,
        body: String
    ) {
        note.chapterNumber = chapterNumber
        note.endChapter = endChapter
        note.title = title
        note.body = body
        note.updatedAt = Date()
    }

    /// Delete a note. Removing it from the book's relationship first drops it
    /// from the Chapters list live (same materialized-array reason as `addNote`).
    static func delete(_ note: ChapterNote, in context: ModelContext) {
        note.book?.chapterNotes.removeAll { $0 === note }
        context.delete(note)
    }
}
