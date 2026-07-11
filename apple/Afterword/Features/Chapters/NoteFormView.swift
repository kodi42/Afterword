import SwiftUI
import SwiftData

/// Add or edit a chapter note. Adding advances the book's progress (forward only,
/// via `ChapterOperations.addNote`); editing never moves progress. A note can
/// cover a single chapter or a range (chapter → optional "through"). Roomy,
/// distraction-free editor: compact fields up top, a full-height body below.
struct NoteFormView: View {
    @Bindable var book: Book
    let defaultChapter: Int
    let note: ChapterNote?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var chapter: String
    @State private var endChapter: String
    @State private var title: String
    @State private var bodyText: String
    @FocusState private var focus: Field?

    private enum Field { case chapter, endChapter, title, body }

    init(book: Book, defaultChapter: Int, note: ChapterNote?) {
        self.book = book
        self.defaultChapter = defaultChapter
        self.note = note
        _chapter = State(initialValue: String(note?.chapterNumber ?? defaultChapter))
        _endChapter = State(initialValue: note?.endChapter.map(String.init) ?? "")
        _title = State(initialValue: note?.title ?? "")
        _bodyText = State(initialValue: note?.body ?? "")
    }

    private var isEdit: Bool { note != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.md) {
                fields
                bodyEditor
            }
            .padding(Theme.Space.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.bg)
            .navigationTitle(isEdit ? "Edit note" : "New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Save" : "Add") { save() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
        }
        .presentationDetents([.large])
        .tint(Theme.Palette.accent)
    }

    private var fields: some View {
        VStack(spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.sm) {
                TextField("Chapter", text: $chapter)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .chapter)
                Text("through")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.inkFaint)
                TextField("End (optional)", text: $endChapter)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .endChapter)
            }
            Divider()
            TextField("Title (optional)", text: $title)
                .focused($focus, equals: .title)
        }
        .cardStyle()
    }

    private var bodyEditor: some View {
        ZStack(alignment: .topLeading) {
            if bodyText.isEmpty {
                Text("What happened / your thoughts…")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.inkFaint)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $bodyText)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.ink)
                .scrollContentBackground(.hidden)
                .focused($focus, equals: .body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardStyle()
    }

    private func save() {
        let start = Int(chapter.trimmingCharacters(in: .whitespaces))
            ?? note?.chapterNumber ?? defaultChapter
        // Only keep an end chapter that actually extends past the start.
        let end = Int(endChapter.trimmingCharacters(in: .whitespaces)).flatMap { $0 > start ? $0 : nil }
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let note {
            ChapterOperations.update(note, chapterNumber: start, endChapter: end, title: title.trimmedNonEmpty, body: cleanBody)
        } else {
            ChapterOperations.addNote(to: book, chapterNumber: start, endChapter: end, title: title.trimmedNonEmpty, body: cleanBody, in: context)
        }
        dismiss()
    }
}
