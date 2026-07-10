import SwiftUI
import SwiftData

/// The Chapters tab: add a note for the next chapter, list past notes
/// newest-chapter-first, swipe to edit/delete. `jumpChapter` scrolls to and
/// briefly highlights a note (from a reference tag or search result) — native
/// `ScrollViewReader` makes the RN scroll-timing bug a non-issue.
struct ChaptersView: View {
    @Bindable var book: Book
    @Binding var jumpChapter: Int?
    @Environment(\.modelContext) private var context

    @State private var showingAdd = false
    @State private var editingNote: ChapterNote?
    @State private var pendingDelete: ChapterNote?
    @State private var highlighted: Int?

    private var notes: [ChapterNote] {
        book.chapterNotes.sorted {
            $0.chapterNumber != $1.chapterNumber
                ? $0.chapterNumber > $1.chapterNumber
                : $0.createdAt > $1.createdAt
        }
    }
    private var nextChapter: Int { (notes.map(\.chapterNumber).max() ?? 0) + 1 }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Button("Add note for chapter \(nextChapter)") { showingAdd = true }
                    .buttonStyle(.afterwordPrimary)
                    .plainListRow()

                if notes.isEmpty {
                    ContentUnavailableView("No chapter notes yet", systemImage: "text.book.closed",
                                           description: Text("Finish a chapter, then jot down what happened and what you thought."))
                        .plainListRow()
                }

                ForEach(notes) { note in
                    noteCard(note)
                        .plainListRow()
                        .id(note.chapterNumber)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { pendingDelete = note } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { editingNote = note } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Theme.Palette.accent)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: jumpChapter, initial: true) { _, target in
                guard let target else { return }
                // A short delay lets the List lay out its rows (covers the
                // deep-link case where the value is already set on first appear).
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                }
                flashHighlight(target)
                jumpChapter = nil
            }
        }
        .sheet(isPresented: $showingAdd) {
            NoteFormView(book: book, defaultChapter: nextChapter, note: nil)
        }
        .sheet(item: $editingNote) { note in
            NoteFormView(book: book, defaultChapter: nextChapter, note: note)
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { note in
            Button("Delete", role: .destructive) { context.delete(note) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This can't be undone.") }
    }

    private func noteCard(_ note: ChapterNote) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Chapter \(note.chapterNumber)" + (note.title.map { " — \($0)" } ?? ""))
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Palette.accent)
            Text(note.body.isEmpty ? "(empty)" : note.body)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.ink)
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(highlighted == note.chapterNumber ? Theme.Palette.accent : .clear, lineWidth: 2)
        )
    }

    private func flashHighlight(_ chapter: Int) {
        highlighted = chapter
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if highlighted == chapter { highlighted = nil }
        }
    }
}
