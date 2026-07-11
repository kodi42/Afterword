import SwiftUI
import SwiftData

/// Add / edit a book. Cover images are found by searching Apple Books then Open
/// Library for the title (no camera roll); the picked thumbnail is downloaded +
/// persisted only on save, so we don't fetch covers the reader never keeps. Port
/// of the RN `BookForm` + `book/new` + `book/edit`.
struct BookFormView: View {
    enum Mode { case add, edit(Book) }

    let mode: Mode
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var author: String
    @State private var totalChapters: String
    @State private var savedCoverName: String?     // existing cover (edit)
    @State private var pickedURL: URL?             // remote pick, downloaded on save
    @State private var removed = false
    @State private var results: [CoverResult] = []
    @State private var searching = false
    @State private var message: String?
    @State private var saving = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _author = State(initialValue: "")
            _totalChapters = State(initialValue: "")
            _savedCoverName = State(initialValue: nil)
        case .edit(let book):
            _title = State(initialValue: book.title)
            _author = State(initialValue: book.author ?? "")
            _totalChapters = State(initialValue: book.totalChapters.map(String.init) ?? "")
            _savedCoverName = State(initialValue: book.coverLocalPath)
        }
    }

    private var isEdit: Bool { if case .edit = mode { return true } else { return false } }
    private var previewShown: Bool { pickedURL != nil || (!removed && savedCoverName != nil) }
    private var canSave: Bool { title.trimmedNonEmpty != nil && !saving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    coverRow
                    if let message {
                        Text(message).font(Theme.Font.caption).foregroundStyle(Theme.Palette.inkSoft)
                    }
                    if !results.isEmpty { resultsStrip }
                }
                Section {
                    TextField("Title", text: $title)
                    TextField("Author (optional)", text: $author)
                    TextField("Total chapters (optional)", text: $totalChapters)
                        .keyboardType(.numberPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .navigationTitle(isEdit ? "Edit book" : "Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
        }
        .tint(Theme.Palette.accent)
    }

    private var coverRow: some View {
        HStack(spacing: Theme.Space.md) {
            coverPreview
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Button {
                    Task { await findCovers() }
                } label: {
                    Text(previewShown ? "Find a different cover" : "Find cover")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Palette.accent)
                }
                .buttonStyle(.plain)
                .disabled(title.trimmedNonEmpty == nil || searching)

                Text("Searches Apple Books, then Open Library.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.inkFaint)

                if previewShown {
                    Button("Remove", role: .destructive) { removeCover() }
                        .font(Theme.Font.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            Spacer(minLength: 0)
            if searching { ProgressView() }
        }
        .padding(.vertical, Theme.Space.xs)
    }

    @ViewBuilder private var coverPreview: some View {
        if let url = pickedURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Theme.Palette.surfaceAlt
            }
            .frame(width: 72, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        } else if removed {
            BookCover(coverName: nil, width: 72)
        } else {
            BookCover(coverName: savedCoverName, width: 72)
        }
    }

    private var resultsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                ForEach(results) { result in
                    Button {
                        pickedURL = result.thumbnailURL
                        removed = false
                    } label: {
                        AsyncImage(url: result.thumbnailURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Theme.Palette.surfaceAlt
                        }
                        .frame(width: 66, height: 99)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .strokeBorder(pickedURL == result.thumbnailURL ? Theme.Palette.accent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, Theme.Space.xs)
        }
    }

    private func findCovers() async {
        guard let title = title.trimmedNonEmpty else { return }
        searching = true
        message = nil
        do {
            let found = try await CoverSearch.search(title: title, author: author.trimmedNonEmpty)
            results = found
            if found.isEmpty {
                message = "No covers found — try refining the title."
            } else {
                pickedURL = found.first?.thumbnailURL
                removed = false
            }
        } catch {
            message = "Could not reach the cover service. Check your connection."
        }
        searching = false
    }

    private func removeCover() {
        pickedURL = nil
        removed = true
        results = []
        message = nil
    }

    private func save() async {
        guard let cleanTitle = title.trimmedNonEmpty else { return }
        saving = true
        message = nil
        do {
            var coverName = savedCoverName
            if let url = pickedURL {
                coverName = try await CoverStore.download(from: url)
            } else if removed {
                coverName = nil
            }
            let chapters = Int(totalChapters.trimmingCharacters(in: .whitespaces))
            switch mode {
            case .add:
                _ = BookOperations.create(
                    title: cleanTitle, author: author.trimmedNonEmpty,
                    totalChapters: chapters, coverName: coverName, in: context
                )
            case .edit(let book):
                BookOperations.update(
                    book, title: cleanTitle, author: author.trimmedNonEmpty,
                    totalChapters: chapters, coverName: coverName
                )
            }
            dismiss()
        } catch {
            message = "Could not download that cover. Try another, or save without one."
            saving = false
        }
    }
}
