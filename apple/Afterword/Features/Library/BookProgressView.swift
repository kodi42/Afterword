import SwiftUI

/// Reading progress under a book's title — either the terracotta progress bar or
/// the "Ch X of Y" text, per the reader's Settings preference. Falls back to text
/// whenever the total chapter count is unknown (a bar needs a denominator).
struct BookProgressView: View {
    let book: Book
    @AppStorage(AppSettings.showProgressBar) private var showProgressBar = false

    var body: some View {
        if showProgressBar, let current = book.currentChapter,
           let total = book.totalChapters, total > 0 {
            ChapterProgressBar(current: current, total: total)
                .padding(.top, 2)
        } else if let text = progressText {
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.accent)
                .padding(.top, 2)
        }
    }

    private var progressText: String? {
        if let current = book.currentChapter, let total = book.totalChapters {
            return "Ch \(current) of \(total)"
        }
        if let current = book.currentChapter { return "Ch \(current)" }
        return nil
    }
}
