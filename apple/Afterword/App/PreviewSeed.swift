#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only sample data, inserted when the app launches with `-seedPreview` and
/// the store is empty. Lets us screenshot populated screens during development;
/// never runs in a normal launch or a release build.
enum PreviewSeed {
    static func seedIfNeeded(context: ModelContext, existing: [Book]) {
        guard ProcessInfo.processInfo.arguments.contains("-seedPreview"), existing.isEmpty else { return }

        let got = Book(title: "A Game of Thrones", author: "George R. R. Martin", totalChapters: 73)
        got.currentChapter = 12
        context.insert(got)

        let dune = Book(title: "Dune", author: "Frank Herbert", totalChapters: 48)
        dune.currentChapter = 5
        context.insert(dune)

        let hobbit = Book(title: "The Hobbit", author: "J. R. R. Tolkien", status: .finished)
        hobbit.finishedAt = Date()
        context.insert(hobbit)
    }
}
#endif
