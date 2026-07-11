import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Home screen. Currently-reading shelf up top, finished below, floating add
/// button. Layout (list/cover grid), status filtering, and the trash live here;
/// filtering is done in memory (a personal library is small), which sidesteps
/// SwiftData enum-predicate quirks. Mirrors the RN Library.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @State private var showingAdd = false
    @State private var showingSearch = false
    @State private var showingImporter = false
    @State private var showingSettings = false
    @State private var showingRecentlyDeleted = false
    @State private var importMessage: String?
    @AppStorage(AppSettings.libraryLayout) private var layout: LibraryLayout = .list
    @AppStorage(AppSettings.libraryFilter) private var filter: LibraryFilter = .all

    // Trashed books never appear on the shelves — only in Recently Deleted.
    private var active: [Book] { books.filter { $0.deletedAt == nil } }
    private var reading: [Book] { active.filter { $0.status != .finished } }
    private var finished: [Book] { active.filter { $0.status == .finished } }
    private var deletedCount: Int { books.count - active.count }

    /// The shelves to render for the current filter.
    private var sections: [(title: String, books: [Book])] {
        switch filter {
        case .all: return [("Currently reading", reading), ("Finished", finished)]
        case .reading: return [("Currently reading", reading)]
        case .finished: return [("Finished", finished)]
        }
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 104), spacing: Theme.Space.md)]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Theme.Palette.bg.ignoresSafeArea()
                content
                addButton
            }
            .navigationTitle("Afterword")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { menu }
                if !active.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        filterMenu
                        Button {
                            layout = layout == .list ? .grid : .list
                        } label: {
                            Image(systemName: layout == .list ? "square.grid.2x2" : "list.bullet")
                        }
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
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingRecentlyDeleted) { RecentlyDeletedView() }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Import", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importMessage ?? "") }
        }
        .tint(Theme.Palette.accent)
        .task { BookOperations.purgeExpired(in: context) }
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
        if active.isEmpty {
            ContentUnavailableView {
                Label("No books yet", systemImage: "books.vertical")
            } description: {
                Text("Add the book you're reading now and start logging notes after each chapter.")
            }
        } else if sections.allSatisfy({ $0.books.isEmpty }) {
            ContentUnavailableView {
                Label(filter == .finished ? "No finished books" : "Nothing to read",
                      systemImage: filter == .finished ? "checkmark.circle" : "book")
            } description: {
                Text(filter == .finished
                     ? "Mark a book as finished and it'll show up here."
                     : "Books you're currently reading will show up here.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                    ForEach(sections, id: \.title) { section in
                        shelf(section.title, section.books)
                    }
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
                switch layout {
                case .list:
                    ForEach(items) { book in
                        NavigationLink(value: book) { BookRow(book: book) }
                            .buttonStyle(.plain)
                    }
                case .grid:
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: Theme.Space.md) {
                        ForEach(items) { book in
                            NavigationLink(value: book) { BookGridCell(book: book) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var menu: some View {
        Menu {
            Button { showingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            Button { showingImporter = true } label: {
                Label("Import from Expo…", systemImage: "square.and.arrow.down")
            }
            Button { showingRecentlyDeleted = true } label: {
                Label(deletedCount > 0 ? "Recently Deleted (\(deletedCount))" : "Recently Deleted",
                      systemImage: "trash")
            }
        } label: { Image(systemName: "ellipsis.circle") }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: $filter) {
                ForEach(LibraryFilter.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            Image(systemName: filter == .all
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
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
