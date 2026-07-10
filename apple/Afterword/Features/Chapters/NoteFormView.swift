import SwiftUI
import SwiftData

/// Add or edit a chapter note. Adding advances the book's progress (forward only,
/// via `ChapterOperations.addNote`); editing never moves progress. Port of the RN
/// `NoteForm`.
struct NoteFormView: View {
    @Bindable var book: Book
    let defaultChapter: Int
    let note: ChapterNote?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var chapter: String
    @State private var title: String
    @State private var bodyText: String

    init(book: Book, defaultChapter: Int, note: ChapterNote?) {
        self.book = book
        self.defaultChapter = defaultChapter
        self.note = note
        _chapter = State(initialValue: String(note?.chapterNumber ?? defaultChapter))
        _title = State(initialValue: note?.title ?? "")
        _bodyText = State(initialValue: note?.body ?? "")
    }

    private var isEdit: Bool { note != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chapter", text: $chapter).keyboardType(.numberPad)
                    TextField("Title (optional)", text: $title)
                }
                Section("What happened / your thoughts") {
                    TextField("Write freely…", text: $bodyText, axis: .vertical)
                        .lineLimit(6...)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle(isEdit ? "Edit note" : "New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Save" : "Add") { save() }
                }
            }
        }
        .tint(Theme.Palette.accent)
    }

    private func save() {
        let chapterNumber = Int(chapter.trimmingCharacters(in: .whitespaces))
            ?? note?.chapterNumber ?? defaultChapter
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let note {
            ChapterOperations.update(note, chapterNumber: chapterNumber, title: title.trimmedNonEmpty, body: cleanBody)
        } else {
            ChapterOperations.addNote(to: book, chapterNumber: chapterNumber, title: title.trimmedNonEmpty, body: cleanBody, in: context)
        }
        dismiss()
    }
}
