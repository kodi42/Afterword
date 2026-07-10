import SwiftUI
import SwiftData

/// Add or edit a manual character (the Phase E baseline; Phase F surfaces the
/// rest from markers). Port of the RN `CharacterForm`.
struct CharacterFormView: View {
    @Bindable var book: Book
    let character: Character?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var detail: String
    @State private var firstSeen: String
    @State private var gone: Bool

    init(book: Book, character: Character?) {
        self.book = book
        self.character = character
        _name = State(initialValue: character?.name ?? "")
        _detail = State(initialValue: character?.detail ?? "")
        _firstSeen = State(initialValue: character?.firstSeenChapter.map(String.init) ?? "")
        _gone = State(initialValue: character?.status == .gone)
    }

    private var isEdit: Bool { character != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Who they are (optional)", text: $detail, axis: .vertical).lineLimit(2...)
                }
                Section {
                    TextField("First seen in chapter (optional)", text: $firstSeen).keyboardType(.numberPad)
                    Toggle("Gone (dead / departed)", isOn: $gone)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle(isEdit ? "Edit character" : "Add character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmedNonEmpty == nil)
                }
            }
        }
        .tint(Theme.Palette.accent)
    }

    private func save() {
        guard let cleanName = name.trimmedNonEmpty else { return }
        let chapter = Int(firstSeen.trimmingCharacters(in: .whitespaces))
        let status: CharacterStatus = gone ? .gone : .active
        if let character {
            CharacterOperations.update(character, name: cleanName, detail: detail.trimmedNonEmpty, firstSeenChapter: chapter, status: status)
        } else {
            CharacterOperations.create(name: cleanName, detail: detail.trimmedNonEmpty, firstSeenChapter: chapter, status: status, book: book, in: context)
        }
        dismiss()
    }
}
