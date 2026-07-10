import Foundation
import SwiftData

/// Merge escape hatch for surfaced characters: the `alias` name folds into the
/// `canonical` name at parse time. Both stored normalized (trimmed, lower-cased)
/// to match how the parser groups names.
@Model
final class CharacterAlias {
    var alias: String
    var canonical: String
    var createdAt: Date

    var book: Book?

    init(alias: String, canonical: String, book: Book? = nil) {
        self.alias = alias
        self.canonical = canonical
        self.book = book
        self.createdAt = Date()
    }
}
