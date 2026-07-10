import SwiftUI
import SwiftData

/// Add or edit a manual prediction. Port of the RN `PredictionForm`.
struct PredictionFormView: View {
    @Bindable var book: Book
    let prediction: Prediction?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var prompt: String
    @State private var madeAt: String

    init(book: Book, prediction: Prediction?) {
        self.book = book
        self.prediction = prediction
        _prompt = State(initialValue: prediction?.prompt ?? "")
        _madeAt = State(initialValue: prediction?.madeAtChapter.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your guess", text: $prompt, axis: .vertical).lineLimit(2...)
                    TextField("Guessed at chapter (optional)", text: $madeAt).keyboardType(.numberPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle(prediction == nil ? "New prediction" : "Edit prediction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(prompt.trimmedNonEmpty == nil)
                }
            }
        }
        .tint(Theme.Palette.accent)
    }

    private func save() {
        guard let cleanPrompt = prompt.trimmedNonEmpty else { return }
        let chapter = Int(madeAt.trimmingCharacters(in: .whitespaces))
        if let prediction {
            PredictionOperations.update(prediction, prompt: cleanPrompt, madeAtChapter: chapter)
        } else {
            PredictionOperations.create(prompt: cleanPrompt, madeAtChapter: chapter, book: book, in: context)
        }
        dismiss()
    }
}

/// Resolve a prediction (manual/materialized or surfaced): note what happened,
/// then mark it right or wrong. `onResolve` does the actual write. Port of the RN
/// `AnswerFields`.
struct AnswerPredictionView: View {
    let prompt: String
    var initialOutcome: String = ""
    let onResolve: (_ wasCorrect: Bool, _ outcome: String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(prompt).font(Theme.Font.body).foregroundStyle(Theme.Palette.ink)
                }
                Section("What actually happened (optional)") {
                    TextField("Turned out to be…", text: $outcome, axis: .vertical).lineLimit(3...)
                }
                Section {
                    Button {
                        onResolve(true, outcome.trimmedNonEmpty); dismiss()
                    } label: {
                        Label("Got it right", systemImage: "checkmark.circle").foregroundStyle(Theme.Palette.success)
                    }
                    Button {
                        onResolve(false, outcome.trimmedNonEmpty); dismiss()
                    } label: {
                        Label("Got it wrong", systemImage: "xmark.circle").foregroundStyle(Theme.Palette.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle("Mark answered")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { outcome = initialOutcome }
        }
        .tint(Theme.Palette.accent)
    }
}
