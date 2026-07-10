import Foundation
import SwiftData

enum CharacterStatus: String, Codable, CaseIterable {
    case active, gone   // gone = dead, departed, no longer relevant
}

/// Reference: who is this person again? `detail` is the description (named to
/// avoid colliding with Swift's `description`).
@Model
final class Character {
    var name: String
    var detail: String?
    var firstSeenChapter: Int?
    var status: CharacterStatus
    var createdAt: Date
    var updatedAt: Date

    var book: Book?

    init(
        name: String,
        detail: String? = nil,
        firstSeenChapter: Int? = nil,
        status: CharacterStatus = .active,
        book: Book? = nil
    ) {
        self.name = name
        self.detail = detail
        self.firstSeenChapter = firstSeenChapter
        self.status = status
        self.book = book
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
