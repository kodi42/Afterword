import Foundation
import SwiftData

/// Manual character writes (the Phase E baseline). Mirrors the character half of
/// the RN `src/features/reference/queries.ts`.
enum CharacterOperations {
    @discardableResult
    static func create(
        name: String,
        detail: String?,
        firstSeenChapter: Int?,
        status: CharacterStatus,
        book: Book,
        in context: ModelContext
    ) -> Character {
        let character = Character(name: name, detail: detail, firstSeenChapter: firstSeenChapter, status: status)
        context.insert(character)
        // Append from the parent side so the Characters list refreshes live (see
        // ChapterOperations.addNote for the SwiftData observation detail).
        book.characters.append(character)
        return character
    }

    static func update(
        _ character: Character,
        name: String,
        detail: String?,
        firstSeenChapter: Int?,
        status: CharacterStatus
    ) {
        character.name = name
        character.detail = detail
        character.firstSeenChapter = firstSeenChapter
        character.status = status
        character.updatedAt = Date()
    }

    static func delete(_ character: Character, in context: ModelContext) {
        character.book?.characters.removeAll { $0 === character }
        context.delete(character)
    }
}
