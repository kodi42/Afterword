import SwiftUI
import SwiftData

/// The Reference tab: a search box + a Characters / Highlights / Predictions
/// sub-picker. Each section stacks two layers — entries surfaced live from note
/// markers (Phase F) and manual entries (Phase E baseline). Port of the RN
/// `ReferenceTab`.
struct ReferenceView: View {
    @Bindable var book: Book
    var onJump: (Int) -> Void

    @State private var section: Section = .characters
    @State private var query = ""

    enum Section: String, CaseIterable, Identifiable {
        case characters = "Characters", highlights = "Highlights", predictions = "Predictions"
        var id: String { rawValue }
    }

    private var parsed: MarkerParser.Parsed {
        let notes = book.chapterNotes.map { MarkerParser.NoteInput(chapterNumber: $0.chapterNumber, body: $0.body) }
        return MarkerParser.parse(notes, aliases: AliasOperations.buildMap(book.aliases))
    }

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            TextField("Search reference…", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, Theme.Space.md)

            Picker("", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.md)

            switch section {
            case .characters:
                CharactersSection(book: book, query: query, surfaced: parsed.characters, onJump: onJump)
            case .highlights:
                HighlightsSection(query: query, highlights: parsed.highlights, onJump: onJump)
            case .predictions:
                PredictionsSection(book: book, query: query, surfaced: parsed.predictions, onJump: onJump)
            }
        }
    }
}

/// Case-insensitive match used by every section's search filter.
func referenceMatches(_ query: String, _ fields: String?...) -> Bool {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    if q.isEmpty { return true }
    return fields.contains { ($0 ?? "").lowercased().contains(q) }
}

// MARK: - Characters

private struct CharactersSection: View {
    @Bindable var book: Book
    let query: String
    let surfaced: [MarkerParser.SurfacedCharacter]
    var onJump: (Int) -> Void

    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var editing: Character?
    @State private var pendingDelete: Character?

    private var shownSurfaced: [MarkerParser.SurfacedCharacter] {
        surfaced.filter { referenceMatches(query, $0.name, $0.detail) }
    }
    private var shownManual: [Character] {
        book.characters
            .filter { referenceMatches(query, $0.name, $0.detail) }
            .sorted {
                $0.status.rawValue != $1.status.rawValue
                    ? $0.status.rawValue < $1.status.rawValue
                    : $0.name.localizedCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        List {
            Button("Add character") { showingAdd = true }
                .buttonStyle(.afterwordPrimary).plainListRow()

            if shownSurfaced.isEmpty && shownManual.isEmpty {
                ContentUnavailableView(query.isEmpty ? "No characters yet" : "No matches",
                                       systemImage: "person",
                                       description: Text(query.isEmpty ? "Write `- Name: who they are` in a chapter note, or add one by hand." : ""))
                    .plainListRow()
            }

            ForEach(shownSurfaced) { character in
                SurfacedCharacterCard(book: book, character: character, all: surfaced, onJump: onJump)
                    .plainListRow()
            }

            ForEach(shownManual) { character in
                manualCard(character)
                    .plainListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { pendingDelete = character } label: { Label("Delete", systemImage: "trash") }
                        Button { editing = character } label: { Label("Edit", systemImage: "pencil") }.tint(Theme.Palette.accent)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingAdd) { CharacterFormView(book: book, character: nil) }
        .sheet(item: $editing) { CharacterFormView(book: book, character: $0) }
        .confirmationDialog("Delete this character?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { character in
            Button("Delete", role: .destructive) { CharacterOperations.delete(character, in: context) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This can't be undone.") }
    }

    private func manualCard(_ character: Character) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack {
                Text(character.name).font(Theme.Font.heading).foregroundStyle(Theme.Palette.ink)
                Spacer()
                StatusBadge(text: character.status == .gone ? "Gone" : "Active",
                            tone: character.status == .gone ? .muted : .active)
            }
            if let detail = character.detail { Text(detail).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink) }
            if let first = character.firstSeenChapter {
                Text("First seen in chapter \(first)").font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkFaint)
            }
        }
        .cardStyle()
    }
}

/// A read-only character built from markers: headline + chapter-tagged timeline,
/// with merge (fold into another surfaced name) and unmerge.
private struct SurfacedCharacterCard: View {
    @Bindable var book: Book
    let character: MarkerParser.SurfacedCharacter
    let all: [MarkerParser.SurfacedCharacter]
    var onJump: (Int) -> Void
    @Environment(\.modelContext) private var context

    private var foldedAliases: [CharacterAlias] { book.aliases.filter { $0.canonical == character.key } }
    private var mergeTargets: [MarkerParser.SurfacedCharacter] { all.filter { $0.key != character.key } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text(character.name).font(Theme.Font.heading).foregroundStyle(Theme.Palette.ink)
                Spacer()
                StatusBadge(text: "From notes", tone: .muted)
            }
            if let detail = character.detail {
                Text(detail).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(character.chapters, id: \.self) { chapter in
                        ChapterTag(chapter: chapter) { onJump(chapter) }
                    }
                }
            }
            if !foldedAliases.isEmpty {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(foldedAliases) { alias in
                        Button { AliasOperations.unmerge(alias.alias, book: book, in: context) } label: {
                            Text("also “\(alias.alias)”  ✕").font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSoft)
                                .padding(.horizontal, Theme.Space.sm).padding(.vertical, 4)
                                .background(Theme.Palette.surfaceAlt, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !mergeTargets.isEmpty {
                Menu {
                    ForEach(mergeTargets) { target in
                        Button(target.name) {
                            AliasOperations.merge(character.name, into: target.name, book: book, in: context)
                        }
                    }
                } label: {
                    Label("Merge into…", systemImage: "arrow.triangle.merge")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.accent)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Highlights

private struct HighlightsSection: View {
    let query: String
    let highlights: [MarkerParser.SurfacedHighlight]
    var onJump: (Int) -> Void

    private var shown: [MarkerParser.SurfacedHighlight] {
        highlights.filter { referenceMatches(query, $0.text) }
    }

    var body: some View {
        List {
            if shown.isEmpty {
                ContentUnavailableView(query.isEmpty ? "No highlights yet" : "No matches",
                                       systemImage: "star",
                                       description: Text(query.isEmpty ? "Mark a key beat with a `* ...` line in a chapter note." : ""))
                    .plainListRow()
            }
            ForEach(shown) { highlight in
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text(highlight.text).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink)
                    ChapterTag(chapter: highlight.chapter) { onJump(highlight.chapter) }
                }
                .cardStyle()
                .plainListRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Predictions

private struct PredictionsSection: View {
    @Bindable var book: Book
    let query: String
    let surfaced: [MarkerParser.SurfacedPrediction]
    var onJump: (Int) -> Void

    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var editing: Prediction?
    @State private var pendingDelete: Prediction?
    @State private var answeringStored: Prediction?
    @State private var answeringSurfaced: MarkerParser.SurfacedPrediction?

    private var openSurfaced: [MarkerParser.SurfacedPrediction] {
        let known = PredictionOperations.storedKeys(book.predictions)
        return surfaced.filter { !known.contains($0.key) && referenceMatches(query, $0.text) }
    }
    private var shownStored: [Prediction] {
        book.predictions
            .filter { referenceMatches(query, $0.prompt, $0.outcome) }
            .sorted {
                ($0.status == .open) != ($1.status == .open)
                    ? $0.status == .open
                    : $0.createdAt > $1.createdAt
            }
    }

    var body: some View {
        List {
            Button("Make a prediction") { showingAdd = true }
                .buttonStyle(.afterwordPrimary).plainListRow()

            if openSurfaced.isEmpty && shownStored.isEmpty {
                ContentUnavailableView(query.isEmpty ? "No predictions yet" : "No matches",
                                       systemImage: "questionmark.circle",
                                       description: Text(query.isEmpty ? "Write `? your guess` in a chapter note, then mark it right or wrong." : ""))
                    .plainListRow()
            }

            ForEach(openSurfaced) { prediction in
                surfacedCard(prediction).plainListRow()
            }

            ForEach(shownStored) { prediction in
                storedCard(prediction)
                    .plainListRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { pendingDelete = prediction } label: { Label("Delete", systemImage: "trash") }
                        Button { editing = prediction } label: { Label("Edit", systemImage: "pencil") }.tint(Theme.Palette.accent)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingAdd) { PredictionFormView(book: book, prediction: nil) }
        .sheet(item: $editing) { PredictionFormView(book: book, prediction: $0) }
        .sheet(item: $answeringStored) { prediction in
            AnswerPredictionView(prompt: prediction.prompt, initialOutcome: prediction.outcome ?? "") { correct, outcome in
                PredictionOperations.answer(prediction, wasCorrect: correct, outcome: outcome)
            }
        }
        .sheet(item: $answeringSurfaced) { prediction in
            AnswerPredictionView(prompt: prediction.text) { correct, outcome in
                PredictionOperations.answerSurfaced(prediction, wasCorrect: correct, outcome: outcome, book: book, in: context)
            }
        }
        .confirmationDialog("Delete this prediction?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { prediction in
            Button("Delete", role: .destructive) { PredictionOperations.delete(prediction, in: context) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This can't be undone.") }
    }

    private func surfacedCard(_ prediction: MarkerParser.SurfacedPrediction) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(alignment: .top) {
                Text(prediction.text).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink)
                Spacer()
                StatusBadge(text: "From notes", tone: .muted)
            }
            ChapterTag(chapter: prediction.chapter) { onJump(prediction.chapter) }
            Button("Mark answered") { answeringSurfaced = prediction }
                .font(Theme.Font.label).foregroundStyle(Theme.Palette.accent)
        }
        .cardStyle()
    }

    private func storedCard(_ prediction: Prediction) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(alignment: .top) {
                Text(prediction.prompt).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink)
                Spacer()
                if prediction.status == .answered {
                    StatusBadge(text: prediction.wasCorrect == true ? "Right" : "Wrong",
                                tone: prediction.wasCorrect == true ? .correct : .wrong)
                } else {
                    StatusBadge(text: "Open", tone: .active)
                }
            }
            if let chapter = prediction.madeAtChapter {
                Text("Guessed at chapter \(chapter)").font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkFaint)
            }
            if prediction.status == .answered, let outcome = prediction.outcome {
                Text("What happened: \(outcome)").font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSoft)
            }
            if prediction.status == .open {
                Button("Mark answered") { answeringStored = prediction }
                    .font(Theme.Font.label).foregroundStyle(Theme.Palette.accent)
            } else {
                Button("Reopen") { PredictionOperations.reopen(prediction) }
                    .font(Theme.Font.label).foregroundStyle(Theme.Palette.accent)
            }
        }
        .cardStyle()
    }
}
