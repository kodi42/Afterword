import SwiftUI
import SwiftData

/// Global search from the Library. One box searches every book at once; results
/// group by type and deep-link to the book + the right tab (+ the chapter note
/// for note hits). Port of the RN `app/search.tsx`.
struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var term = ""
    @State private var results = SearchEngine.Results()

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            content
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $term, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search notes and reference…")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onChange(of: term) { _, value in
            results = SearchEngine.search(value, in: context)
        }
    }

    @ViewBuilder private var content: some View {
        if term.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView("Search across every book", systemImage: "magnifyingglass",
                                   description: Text("Chapter notes, characters, and predictions — all at once."))
        } else if results.isEmpty {
            ContentUnavailableView.search(text: term)
        } else {
            List {
                if !results.notes.isEmpty {
                    Section("Chapter notes") {
                        ForEach(results.notes) { noteRow($0) }
                    }
                }
                if !results.characters.isEmpty {
                    Section("Characters") {
                        ForEach(results.characters) { characterRow($0) }
                    }
                }
                if !results.predictions.isEmpty {
                    Section("Predictions") {
                        ForEach(results.predictions) { predictionRow($0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder private func noteRow(_ note: ChapterNote) -> some View {
        if let book = note.book {
            NavigationLink(value: BookJump(book: book, tab: .chapters, jump: note.chapterNumber)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkFaint)
                    Text("Chapter \(note.chapterNumber)" + (note.title.map { " — \($0)" } ?? ""))
                        .font(Theme.Font.heading).foregroundStyle(Theme.Palette.accent)
                    Text(note.body.isEmpty ? "(empty)" : note.body)
                        .font(Theme.Font.body).foregroundStyle(Theme.Palette.ink).lineLimit(2)
                }
            }
            .listRowBackground(Theme.Palette.surface)
        }
    }

    @ViewBuilder private func characterRow(_ character: Character) -> some View {
        if let book = character.book {
            NavigationLink(value: BookJump(book: book, tab: .reference, jump: nil)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkFaint)
                    Text(character.name).font(Theme.Font.heading).foregroundStyle(Theme.Palette.accent)
                    if let detail = character.detail {
                        Text(detail).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink).lineLimit(2)
                    }
                }
            }
            .listRowBackground(Theme.Palette.surface)
        }
    }

    @ViewBuilder private func predictionRow(_ prediction: Prediction) -> some View {
        if let book = prediction.book {
            NavigationLink(value: BookJump(book: book, tab: .reference, jump: nil)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkFaint)
                    Text(prediction.prompt).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink).lineLimit(2)
                    Text(prediction.status == .answered ? "Answered" : "Open")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkFaint)
                }
            }
            .listRowBackground(Theme.Palette.surface)
        }
    }
}
