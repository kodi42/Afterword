import SwiftUI
import SwiftData

/// App entry point. One SwiftData container holds the whole local library; every
/// screen reads it reactively with `@Query` (the native analog of the RN app's
/// `useLiveQuery`). Local-only for now; CloudKit sync is a post-parity add.
@main
struct AfterwordApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Book.self,
            ChapterNote.self,
            Character.self,
            Prediction.self,
            CharacterAlias.self,
        ])
    }
}
