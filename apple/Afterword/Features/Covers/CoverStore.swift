import Foundation

/// Local persistence for cover images (port of the RN `cover.ts`). We store only
/// the **filename** on the book and resolve it against the current Documents dir
/// at read time — robust to the app container path changing across installs.
enum CoverStore {
    private static func coversDirectory() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = docs.appending(path: "covers", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Full file URL for a stored cover filename, or nil if it can't be resolved.
    static func fileURL(for name: String?) -> URL? {
        guard let name, !name.isEmpty, let dir = try? coversDirectory() else { return nil }
        return dir.appending(path: name)
    }

    /// Download a remote cover into Documents/covers and return the stored filename.
    static func download(from url: URL) async throws -> String {
        let (tmp, _) = try await URLSession.shared.download(from: url)
        let name = "\(UUID().uuidString).jpg"
        let dest = try coversDirectory().appending(path: name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        return name
    }

    /// Delete a stored cover file. Safe with a missing/absent name.
    static func delete(name: String?) {
        guard let url = fileURL(for: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
