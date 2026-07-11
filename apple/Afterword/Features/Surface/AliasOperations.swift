import Foundation
import SwiftData

/// Character-merge overlay (port of the alias half of the RN `surface/queries.ts`).
/// A merge folds the surfaced `alias` name into `canonical`; both stored
/// normalized so they match how the parser groups names.
enum AliasOperations {
    /// Fold `aliasName` into `canonicalName`. Re-merging an alias replaces its
    /// previous target. Self-merges are ignored.
    static func merge(_ aliasName: String, into canonicalName: String, book: Book, in context: ModelContext) {
        let alias = MarkerParser.normalizeKey(aliasName)
        let canonical = MarkerParser.normalizeKey(canonicalName)
        guard !alias.isEmpty, !canonical.isEmpty, alias != canonical else { return }

        // Update in place if this alias already folds somewhere — avoids a
        // delete+insert (SwiftData doesn't reflect deletes in the relationship
        // array until the context processes them).
        if let existing = book.aliases.first(where: { $0.alias == alias }) {
            existing.canonical = canonical
        } else {
            let row = CharacterAlias(alias: alias, canonical: canonical)
            context.insert(row)
            book.aliases.append(row) // parent-side so the merge takes effect live
        }
    }

    /// Split a merged name back out.
    static func unmerge(_ aliasName: String, book: Book, in context: ModelContext) {
        let alias = MarkerParser.normalizeKey(aliasName)
        let matches = book.aliases.filter { $0.alias == alias }
        book.aliases.removeAll { $0.alias == alias } // parent-side so it un-folds live
        for existing in matches { context.delete(existing) }
    }

    /// Build the normalized alias -> canonical map the parser expects, flattening
    /// chains so A->B->C resolves straight to C, with a cycle guard.
    static func buildMap(_ aliases: [CharacterAlias]) -> [String: String] {
        var direct: [String: String] = [:]
        for row in aliases { direct[row.alias] = row.canonical }

        var flat: [String: String] = [:]
        for alias in direct.keys {
            var seen: Set<String> = [alias]
            var target = direct[alias]!
            while let next = direct[target], !seen.contains(target) {
                seen.insert(target)
                target = next
            }
            flat[alias] = target
        }
        return flat
    }
}
