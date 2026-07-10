import SwiftUI
import SwiftData

/// App root. The Library owns the navigation stack.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var books: [Book]

    var body: some View {
        LibraryView()
            .task {
                #if DEBUG
                PreviewSeed.seedIfNeeded(context: context, existing: books)
                #endif
            }
    }
}
