import Foundation
import SwiftData

/// Prediction resolve/reopen logic — built once here and reused for both manual
/// predictions and surfaced `?` markers (Phase F), mirroring the RN
/// `answerPrediction` / `reopenPrediction`.
enum PredictionOperations {
    @discardableResult
    static func create(prompt: String, madeAtChapter: Int?, book: Book, in context: ModelContext) -> Prediction {
        let prediction = Prediction(prompt: prompt, madeAtChapter: madeAtChapter, status: .open, book: book)
        context.insert(prediction)
        return prediction
    }

    static func update(_ prediction: Prediction, prompt: String, madeAtChapter: Int?) {
        prediction.prompt = prompt
        prediction.madeAtChapter = madeAtChapter
        prediction.updatedAt = Date()
    }

    static func delete(_ prediction: Prediction, in context: ModelContext) {
        context.delete(prediction)
    }

    /// Answer a surfaced `?` marker: materialize it into the predictions store
    /// (reusing `create` + `answer`), after which the raw line is deduped out of
    /// the surfaced view. Mirrors the RN `answerSurfacedPrediction`.
    static func answerSurfaced(
        _ surfaced: MarkerParser.SurfacedPrediction,
        wasCorrect: Bool,
        outcome: String?,
        book: Book,
        in context: ModelContext
    ) {
        let prediction = create(prompt: surfaced.text, madeAtChapter: surfaced.chapter, book: book, in: context)
        answer(prediction, wasCorrect: wasCorrect, outcome: outcome)
    }

    /// Normalized prompts already stored, so the surfaced view can skip any `?`
    /// line that's been materialized (or manually entered).
    static func storedKeys(_ predictions: [Prediction]) -> Set<String> {
        Set(predictions.map { MarkerParser.normalizeKey($0.prompt) })
    }

    /// Resolve a guess: mark it answered, record correctness and (optionally)
    /// what actually happened.
    static func answer(_ prediction: Prediction, wasCorrect: Bool, outcome: String?) {
        prediction.status = .answered
        prediction.wasCorrect = wasCorrect
        prediction.outcome = outcome?.trimmedNonEmpty
        prediction.updatedAt = Date()
    }

    /// Undo a resolution, dropping the guess back to open.
    static func reopen(_ prediction: Prediction) {
        prediction.status = .open
        prediction.wasCorrect = nil
        prediction.outcome = nil
        prediction.updatedAt = Date()
    }
}
