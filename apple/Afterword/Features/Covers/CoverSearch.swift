import Foundation

/// A cover candidate. `id` is a stable per-source key (Apple track id or Open
/// Library work key / cover id).
struct CoverResult: Identifiable, Hashable {
    let id: String
    let title: String
    let authors: String
    let thumbnailURL: URL
}

/// Cover search across two keyless, free sources, modern-first:
///  1. **Apple Books** (the iTunes Search API) — current commercial editions with
///     high-resolution artwork, so we stop recommending only dated library scans.
///  2. **Open Library** — appended as a fallback so obscure / out-of-print titles
///     Apple doesn't sell still turn up a cover.
///
/// Google Books is deliberately avoided: its keyless anonymous quota is globally
/// exhausted and 429s. Port of the RN `src/features/books/coverSearch.ts`. The
/// `parse*` and `*URL` helpers are pure so they're unit-testable.
enum CoverSearch {

    // MARK: - Public entry point

    /// Fetch cover candidates, Apple Books first then Open Library, de-duped.
    /// Each source is queried concurrently and tolerated independently: if only
    /// one fails we still return the other's covers; only when *both* error do we
    /// throw (so the UI can show a connection message).
    static func search(title: String, author: String?) async throws -> [CoverResult] {
        guard title.trimmedNonEmpty != nil else { return [] }
        async let apple = fetchAppleOrNil(title: title, author: author)
        async let openLibrary = fetchOpenLibraryOrNil(title: title, author: author)
        let appleResults = await apple
        let openLibraryResults = await openLibrary
        guard appleResults != nil || openLibraryResults != nil else {
            throw URLError(.badServerResponse)  // both sources failed
        }
        return dedupe((appleResults ?? []) + (openLibraryResults ?? []))
    }

    /// De-dupe a merged list, keeping first (Apple) occurrence. Guards on both the
    /// image URL and `id` so `ForEach` never sees a repeated Identifiable id.
    private static func dedupe(_ results: [CoverResult]) -> [CoverResult] {
        var seenURL = Set<String>()
        var seenID = Set<String>()
        var out: [CoverResult] = []
        for result in results {
            let url = result.thumbnailURL.absoluteString
            guard !seenURL.contains(url), !seenID.contains(result.id) else { continue }
            seenURL.insert(url)
            seenID.insert(result.id)
            out.append(result)
        }
        return out
    }

    private static func fetchAppleOrNil(title: String, author: String?) async -> [CoverResult]? {
        try? await searchAppleBooks(title: title, author: author)
    }

    private static func fetchOpenLibraryOrNil(title: String, author: String?) async -> [CoverResult]? {
        try? await searchOpenLibrary(title: title, author: author)
    }

    // MARK: - Apple Books (iTunes Search API)

    private struct AppleResponse: Decodable { let results: [AppleDoc]? }
    private struct AppleDoc: Decodable {
        let trackId: Int?
        let trackName: String?
        let artistName: String?
        let artworkUrl100: String?
    }

    /// The iTunes Search API returns a small `artworkUrl100` (100px). Rewrite the
    /// dimensions segment to request a crisp 600px render of the same artwork.
    static func appleArtworkURL(_ raw: String) -> URL? {
        let hiRes = raw.replacingOccurrences(
            of: #"/\d+x\d+bb\."#,
            with: "/600x600bb.",
            options: .regularExpression
        )
        return URL(string: hiRes)
    }

    static func appleSearchURL(title: String, author: String?) -> URL {
        var terms = [title.trimmingCharacters(in: .whitespaces)]
        if let author = author?.trimmedNonEmpty { terms.append(author) }
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "ebook"),
            URLQueryItem(name: "term", value: terms.joined(separator: " ")),
            URLQueryItem(name: "limit", value: "12"),
            URLQueryItem(name: "country", value: "US"),
        ]
        return components.url!
    }

    /// Keep only docs with usable artwork, de-dupe by track id, preserve the API's
    /// relevance order so the first result is the best modern default.
    static func parseAppleBooks(_ data: Data) throws -> [CoverResult] {
        let response = try JSONDecoder().decode(AppleResponse.self, from: data)
        var out: [CoverResult] = []
        var seen = Set<Int>()
        for doc in response.results ?? [] {
            guard let raw = doc.artworkUrl100, let url = appleArtworkURL(raw) else { continue }
            if let trackId = doc.trackId {
                guard !seen.contains(trackId) else { continue }
                seen.insert(trackId)
            }
            out.append(
                CoverResult(
                    id: doc.trackId.map { "apple-\($0)" } ?? raw,
                    title: doc.trackName ?? "",
                    authors: doc.artistName ?? "",
                    thumbnailURL: url
                )
            )
        }
        return out
    }

    static func searchAppleBooks(title: String, author: String?) async throws -> [CoverResult] {
        guard title.trimmedNonEmpty != nil else { return [] }
        let (data, response) = try await URLSession.shared.data(from: appleSearchURL(title: title, author: author))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try parseAppleBooks(data)
    }

    // MARK: - Open Library

    private struct Response: Decodable { let docs: [Doc]? }
    private struct Doc: Decodable {
        let key: String?
        let title: String?
        let author_name: [String]?
        let cover_i: Int?
    }

    /// Open Library cover image url for a numeric cover id. M ≈ 180px wide.
    static func coverImageURL(id: Int, size: String = "M") -> URL {
        URL(string: "https://covers.openlibrary.org/b/id/\(id)-\(size).jpg")!
    }

    /// Keep only docs with a real cover (`cover_i`), de-dupe, preserve relevance
    /// order.
    static func parseOpenLibrary(_ data: Data) throws -> [CoverResult] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        var out: [CoverResult] = []
        var seen = Set<Int>()
        for doc in response.docs ?? [] {
            guard let cover = doc.cover_i, !seen.contains(cover) else { continue }
            seen.insert(cover)
            out.append(
                CoverResult(
                    id: doc.key ?? String(cover),
                    title: doc.title ?? "",
                    authors: doc.author_name?.joined(separator: ", ") ?? "",
                    thumbnailURL: coverImageURL(id: cover)
                )
            )
        }
        return out
    }

    static func openLibrarySearchURL(title: String, author: String?) -> URL {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        var items = [
            URLQueryItem(name: "title", value: title.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "limit", value: "12"),
            URLQueryItem(name: "fields", value: "key,title,author_name,cover_i"),
        ]
        if let author = author?.trimmedNonEmpty {
            items.append(URLQueryItem(name: "author", value: author))
        }
        components.queryItems = items
        return components.url!
    }

    static func searchOpenLibrary(title: String, author: String?) async throws -> [CoverResult] {
        guard title.trimmedNonEmpty != nil else { return [] }
        let (data, response) = try await URLSession.shared.data(from: openLibrarySearchURL(title: title, author: author))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try parseOpenLibrary(data)
    }
}
