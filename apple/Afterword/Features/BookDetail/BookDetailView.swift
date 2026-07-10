import SwiftUI
import SwiftData

/// Book detail: header (cover, title, author, finished tag, actions menu) over a
/// Chapters / Reference segmented control. Port of the RN `app/book/[id].tsx`.
struct BookDetailView: View {
    @Bindable var book: Book
    /// Where to land (search results deep-link straight to Reference or to a note).
    var initialTab: DetailTab = .chapters
    var initialJump: Int?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var tab: DetailTab = .chapters
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var appliedInitial = false
    /// Cross-tab jump target: set to a chapter number to switch to Chapters and
    /// scroll there (used by reference tags in Phase F and search in Phase G).
    @State private var jumpChapter: Int?

    enum DetailTab: String, CaseIterable, Identifiable {
        case chapters = "Chapters", reference = "Reference"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: Theme.Space.md) {
                header
                Picker("", selection: $tab) {
                    ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Space.md)

                switch tab {
                case .chapters:
                    ChaptersView(book: book, jumpChapter: $jumpChapter)
                case .reference:
                    ReferenceView(book: book) { chapter in
                        tab = .chapters
                        jumpChapter = chapter
                    }
                }
            }
            .padding(.top, Theme.Space.sm)
            .animation(.snappy, value: tab)
        }
        .sensoryFeedback(.selection, trigger: tab)
        .sensoryFeedback(.success, trigger: book.status)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !appliedInitial else { return }
            appliedInitial = true
            if let initialJump {
                tab = .chapters
                jumpChapter = initialJump
            } else {
                tab = initialTab
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { menu } }
        .sheet(isPresented: $showingEdit) { BookFormView(mode: .edit(book)) }
        .confirmationDialog("Delete this book?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                BookOperations.delete(book, in: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its chapter notes and reference entries go too. This can't be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            BookCover(coverName: book.coverLocalPath, width: 56)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Space.sm) {
                    Text(book.title)
                        .font(Theme.Font.title)
                        .foregroundStyle(Theme.Palette.ink)
                    if book.status == .finished {
                        Text("Finished")
                            .font(Theme.Font.caption).fontWeight(.semibold)
                            .foregroundStyle(Theme.Palette.success)
                    }
                }
                if let author = book.author, !author.isEmpty {
                    Text(author).font(Theme.Font.body).foregroundStyle(Theme.Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.md)
    }

    private var menu: some View {
        Menu {
            Button { showingEdit = true } label: { Label("Edit details", systemImage: "pencil") }
            if book.status == .finished {
                Button { BookOperations.markReading(book) } label: {
                    Label("Move back to reading", systemImage: "book")
                }
            } else {
                Button { BookOperations.markFinished(book) } label: {
                    Label("Mark as finished", systemImage: "checkmark.circle")
                }
            }
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("Delete book", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

/// Navigation value for a deep-link into a book at a specific tab (and optional
/// chapter note). Used by search results.
struct BookJump: Hashable {
    let book: Book
    let tab: BookDetailView.DetailTab
    let jump: Int?
}
