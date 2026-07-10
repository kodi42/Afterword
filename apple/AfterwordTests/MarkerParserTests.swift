import Testing
@testable import Afterword

/// Port of the RN `tests/parser.test.ts`, case-for-case.
struct MarkerParserTests {
    private func note(_ chapter: Int, _ body: String) -> MarkerParser.NoteInput {
        MarkerParser.NoteInput(chapterNumber: chapter, body: body)
    }

    @Test func normalizeKeyTrimsFlattensLowercases() {
        #expect(MarkerParser.normalizeKey("  Ned   Stark ") == "ned stark")
    }

    @Test func extractsCharacterIgnoringProseAndColonlessBullets() {
        let parsed = MarkerParser.parse([
            note(1, "Intro paragraph.\n- Ned: Warden of the North\n- just a bullet\nsome - dash in prose")
        ])
        #expect(parsed.characters.count == 1)
        #expect(parsed.characters[0].name == "Ned")
        #expect(parsed.characters[0].detail == "Warden of the North")
    }

    @Test func groupsCaseInsensitivelyWithTimeline() {
        let parsed = MarkerParser.parse([
            note(3, "- ned: still brooding"),
            note(1, "- Ned: Warden of the North"),
        ])
        #expect(parsed.characters.count == 1)
        let ned = parsed.characters[0]
        #expect(ned.firstSeenChapter == 1)
        #expect(ned.chapters == [1, 3])
        #expect(ned.detail == "Warden of the North") // earliest headline
        #expect(ned.mentions.map(\.chapter) == [1, 3])
    }

    @Test func foldsAliases() {
        let parsed = MarkerParser.parse(
            [note(1, "- Ned: lord"), note(2, "- Eddard: same guy")],
            aliases: ["eddard": "ned"]
        )
        #expect(parsed.characters.count == 1)
        #expect(parsed.characters[0].chapters == [1, 2])
    }

    @Test func sortsCharactersByFirstSeen() {
        let parsed = MarkerParser.parse([
            note(1, "- Ned: a"), note(2, "- Jon: b"), note(3, "- Robert: c"),
        ])
        #expect(parsed.characters.map(\.name) == ["Ned", "Jon", "Robert"])
    }

    @Test func collectsHighlightsNewestFirst() {
        let parsed = MarkerParser.parse([
            note(1, "* The king arrives"), note(2, "* Duel at the tower"),
        ])
        #expect(parsed.highlights.map(\.text) == ["Duel at the tower", "The king arrives"])
    }

    @Test func collectsPredictionsNewestFirstWithKey() {
        let parsed = MarkerParser.parse([
            note(1, "? Ned will die"), note(3, "?  Winter is coming"),
        ])
        #expect(parsed.predictions.map(\.text) == ["Winter is coming", "Ned will die"])
        #expect(parsed.predictions[0].key == "winter is coming")
    }

    @Test func neverMisreadsMarkersInsideProse() {
        let parsed = MarkerParser.parse([
            note(1, "What happens next? Nobody knows. A star * is not a marker.")
        ])
        #expect(parsed.highlights.isEmpty)
        #expect(parsed.predictions.isEmpty)
    }
}
