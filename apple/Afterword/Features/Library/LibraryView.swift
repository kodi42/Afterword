import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Home screen. Currently-reading shelf up top, finished below, floating add
/// button. Status filtering is done in memory (a personal library is small),
/// which sidesteps SwiftData enum-predicate quirks. Mirrors the RN Library.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @State private var showingAdd = false
    @State private var showingSearch = false
    @State private var showingImporter = false
    @State private var importMessage: String?

    private var reading: [Book] { books.filter { $0.status != .finished } }
    private var finished: [Book] { books.filter { $0.status == .finished } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Theme.Palette.bg.ignoresSafeArea()
                content
                addButton
            }
            .navigationTitle("Afterword")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { showingImporter = true } label: {
                            Label("Import from Expo…", systemImage: "square.and.arrow.down")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                if !books.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingSearch = true } label: { Image(systemName: "magnifyingglass") }
                    }
                }
            }
            .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
            .navigationDestination(for: BookJump.self) {
                BookDetailView(book: $0.book, initialTab: $0.tab, initialJump: $0.jump)
            }
            .navigationDestination(isPresented: $showingSearch) { SearchView() }
            .sheet(isPresented: $showingAdd) { BookFormView(mode: .add) }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Import", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importMessage ?? "") }
        }
        .tint(Theme.Palette.accent)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let summary = try ImportService.importFile(at: url, into: context)
                importMessage = "Imported \(summary.books) book\(summary.books == 1 ? "" : "s"), "
                    + "\(summary.notes) notes, \(summary.characters) characters, \(summary.predictions) predictions."
            } catch {
                importMessage = (error as? ImportService.ImportError)?.message ?? error.localizedDescription
            }
        case .failure(let error):
            importMessage = error.localizedDescription
        }
    }

    @ViewBuilder private var content: some View {
        if books.isEmpty {
            ContentUnavailableView {
                Label("No books yet", systemImage: "books.vertical")
            } description: {
                Text("Add the book you're reading now and start logging notes after each chapter.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                    shelf("Currently reading", reading)
                    shelf("Finished", finished)
                }
                .padding(Theme.Space.md)
                .padding(.bottom, 96)
            }
        }
    }

    @ViewBuilder private func shelf(_ title: String, _ items: [Book]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text(title.uppercased())
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Palette.inkSoft)
                    .kerning(0.5)
                ForEach(items) { book in
                    NavigationLink(value: book) {
                        BookRow(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.Palette.accent, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(Theme.Space.lg)
    }
}
