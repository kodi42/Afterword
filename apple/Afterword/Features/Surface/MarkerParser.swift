import Foundation

/// MARKER PARSER — the surfacing engine, ported from `src/features/surface/parser.ts`.
/// Pure string work: no SwiftData, no network, no cost. Reads marker lines the
/// reader already types into chapter notes and turns them into reference entries.
///
///   - Name: description   -> a character
///   * something           -> a highlight
///   ? something           -> a prediction
///
/// A line only counts if it *starts* with the marker (after optional whitespace),
/// so ordinary prose is never misread. Deterministic; re-runs from scratch on
/// every read, so the surfaced view always reflects current note text.
enum MarkerParser {
    /// Lightweight input so the parser stays decoupled from SwiftData (and trivial
    /// to unit-test).
    struct NoteInput {
        let chapterNumber: Int
        let body: String
        init(chapterNumber: Int, body: String) {
            self.chapterNumber = chapterNumber
            self.body = body
        }
    }

    struct CharacterMention: Hashable {
        let chapter: Int
        let detail: String?
    }

    struct SurfacedCharacter: Identifiable, Hashable {
        let key: String            // normalized canonical name — stable id
        let name: String           // display name (earliest mention)
        let detail: String?        // headline: earliest non-empty description
        let firstSeenChapter: Int
        let chapters: [Int]        // every chapter it appears in, ascending
        let mentions: [CharacterMention]
        var id: String { key }
    }

    struct SurfacedHighlight: Identifiable, Hashable {
        let id: Int
        let chapter: Int
        let text: String
    }

    struct SurfacedPrediction: Identifiable, Hashable {
        let id: Int
        let key: String            // normalized prompt — matches materialized rows
        let chapter: Int
        let text: String
    }

    struct Parsed {
        let characters: [SurfacedCharacter]
        let highlights: [SurfacedHighlight]
        let predictions: [SurfacedPrediction]
    }

    /// Collapse a name/prompt to its grouping key: trimmed, whitespace-flattened, lower-cased.
    static func normalizeKey(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    /// Parse every note's body for markers. `aliases` maps normalized-alias ->
    /// normalized-canonical (already chain-flattened by `AliasOperations`).
    static func parse(_ notes: [NoteInput], aliases: [String: String] = [:]) -> Parsed {
        var rawCharacters: [(name: String, chapter: Int, detail: String?, order: Int)] = []
        var highlights: [SurfacedHighlight] = []
        var predictions: [SurfacedPrediction] = []
        var order = 0

        for note in notes {
            for rawLine in note.body.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }
                order += 1

                if let (name, detail) = matchCharacter(line) {
                    rawCharacters.append((name, note.chapterNumber, detail, order))
                } else if let text = matchMarker(line, "*") {
                    highlights.append(SurfacedHighlight(id: order, chapter: note.chapterNumber, text: text))
                } else if let text = matchMarker(line, "?") {
                    predictions.append(SurfacedPrediction(id: order, key: normalizeKey(text),
                                                          chapter: note.chapterNumber, text: text))
                }
            }
        }

        return Parsed(
            characters: groupCharacters(rawCharacters, aliases: aliases),
            highlights: highlights.sorted { $0.chapter != $1.chapter ? $0.chapter > $1.chapter : $0.id < $1.id },
            predictions: predictions.sorted { $0.chapter != $1.chapter ? $0.chapter > $1.chapter : $0.id < $1.id }
        )
    }

    // MARK: - Line matching

    /// `- Name: description` — requires whitespace after the dash and a colon, so
    /// plain bullets and prose dashes are ignored.
    private static func matchCharacter(_ line: String) -> (name: String, detail: String?)? {
        guard line.hasPrefix("-") else { return nil }
        let afterDash = line.dropFirst()
        guard let first = afterDash.first, first == " " || first == "\t" else { return nil }
        let rest = afterDash.drop { $0 == " " || $0 == "\t" }
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let name = rest[rest.startIndex..<colon].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let detail = rest[rest.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return (name, detail.isEmpty ? nil : detail)
    }

    /// `* something` / `? something` — requires whitespace after the marker and
    /// non-empty text.
    private static func matchMarker(_ line: String, _ marker: String) -> String? {
        guard line.hasPrefix(marker) else { return nil }
        let after = line.dropFirst(marker.count)
        guard let first = after.first, first == " " || first == "\t" else { return nil }
        let text = after.drop { $0 == " " || $0 == "\t" }.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    // MARK: - Grouping

    private static func groupCharacters(
        _ raw: [(name: String, chapter: Int, detail: String?, order: Int)],
        aliases: [String: String]
    ) -> [SurfacedCharacter] {
        var groups: [String: [(name: String, chapter: Int, detail: String?, order: Int)]] = [:]
        for mention in raw {
            let rawKey = normalizeKey(mention.name)
            let key = aliases[rawKey] ?? rawKey
            groups[key, default: []].append(mention)
        }

        var result: [SurfacedCharacter] = []
        for (key, mentions) in groups {
            let ordered = mentions.sorted { $0.chapter != $1.chapter ? $0.chapter < $1.chapter : $0.order < $1.order }

            var seen = Set<Int>()
            var chapters: [Int] = []
            for m in ordered where !seen.contains(m.chapter) {
                seen.insert(m.chapter)
                chapters.append(m.chapter)
            }

            result.append(
                SurfacedCharacter(
                    key: key,
                    name: ordered[0].name,
                    detail: ordered.compactMap(\.detail).first, // earliest non-empty
                    firstSeenChapter: ordered[0].chapter,
                    chapters: chapters,
                    mentions: ordered.map { CharacterMention(chapter: $0.chapter, detail: $0.detail) }
                )
            )
        }

        return result.sorted {
            $0.firstSeenChapter != $1.firstSeenChapter
                ? $0.firstSeenChapter < $1.firstSeenChapter
                : $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }
}
