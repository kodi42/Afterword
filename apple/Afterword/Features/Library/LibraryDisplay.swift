import Foundation

/// UserDefaults keys for the lightweight display preferences the reader controls
/// (read via `@AppStorage`). Centralized so the toolbar toggle and the Settings
/// screen share one source of truth instead of stringly-typed keys.
enum AppSettings {
    static let showProgressBar = "showProgressBar"
    static let libraryLayout = "libraryLayout"
    static let libraryFilter = "libraryFilter"
}

/// How the Library shelf lays books out: a text-forward list or a cover grid.
enum LibraryLayout: String, CaseIterable {
    case list, grid
}

/// Which shelf the Library shows. `.all` keeps the reading/finished split.
enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, reading, finished
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All books"
        case .reading: return "Currently reading"
        case .finished: return "Finished"
        }
    }
}
