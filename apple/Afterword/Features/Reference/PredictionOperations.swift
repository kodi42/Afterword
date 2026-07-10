import Foundation

/// Prediction resolve/reopen logic — built once here and reused for both manual
/// predictions and surfaced `?` markers (Phase F), mirroring the RN
/// `answerPrediction` / `reopenPrediction`.
enum PredictionOperations {
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
