import Foundation
import SwiftData

enum PredictionStatus: String, Codable, CaseIterable {
    case open, answered
}

/// Reference: a guess made while reading, later marked right or wrong. Surfaced
/// `? ...` markers materialize into this table when they're answered.
@Model
final class Prediction {
    var prompt: String
    var madeAtChapter: Int?
    var status: PredictionStatus
    var outcome: String?
    var wasCorrect: Bool?
    var createdAt: Date
    var updatedAt: Date

    var book: Book?

    init(
        prompt: String,
        madeAtChapter: Int? = nil,
        status: PredictionStatus = .open,
        book: Book? = nil
    ) {
        self.prompt = prompt
        self.madeAtChapter = madeAtChapter
        self.status = status
        self.book = book
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
