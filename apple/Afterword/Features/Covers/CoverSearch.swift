import Foundation

/// A cover candidate from Open Library. `id` is the work key (or cover id).
struct CoverResult: Identifiable, Hashable {
    let id: String
    let title: String
    let authors: String
    let thumbnailURL: URL
}

/// Cover search via the Open Library API — keyless, free, reliable (unlike keyless
/// Google Books, which shares a globally-exhausted quota). Port of the RN
/// `src/features/books/coverSearch.ts`. `parse` is pure so it's unit-testable.
enum CoverSearch {
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
    /// order so the first result is the best default.
    static func parse(_ data: Data) throws -> [CoverResult] {
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

    static func searchURL(title: String, author: String?) -> URL {
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

    /// Fetch cover candidates. Throws on a network/HTTP failure.
    static func search(title: String, author: String?) async throws -> [CoverResult] {
        guard title.trimmedNonEmpty != nil else { return [] }
        let (data, response) = try await URLSession.shared.data(from: searchURL(title: title, author: author))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try parse(data)
    }
}
