import Testing
import Foundation
@testable import Afterword

/// Port of the RN `tests/coverSearch.test.ts` — validates Open Library response
/// parsing (pure, no network).
struct CoverSearchTests {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test func returnsEmptyForEmptyDocs() throws {
        #expect(try CoverSearch.parse(data(#"{"docs":[]}"#)).isEmpty)
        #expect(try CoverSearch.parse(data(#"{}"#)).isEmpty)
    }

    @Test func mapsDocsToCoverURLs() throws {
        let json = #"""
        {"docs":[{"key":"/works/OL1W","title":"Throne of Glass","author_name":["Sarah J. Maas"],"cover_i":13312488}]}
        """#
        let results = try CoverSearch.parse(data(json))
        #expect(results.count == 1)
        #expect(results[0].id == "/works/OL1W")
        #expect(results[0].title == "Throne of Glass")
        #expect(results[0].authors == "Sarah J. Maas")
        #expect(results[0].thumbnailURL.absoluteString == "https://covers.openlibrary.org/b/id/13312488-M.jpg")
    }

    @Test func skipsDocsWithoutCover() throws {
        let json = #"""
        {"docs":[{"key":"/works/A","title":"No Cover"},{"key":"/works/B","title":"Has Cover","cover_i":42}]}
        """#
        let results = try CoverSearch.parse(data(json))
        #expect(results.count == 1)
        #expect(results[0].id == "/works/B")
    }

    @Test func dedupesRepeatedCoverIDs() throws {
        let json = #"{"docs":[{"key":"/works/A","cover_i":7},{"key":"/works/B","cover_i":7}]}"#
        #expect(try CoverSearch.parse(data(json)).count == 1)
    }

    @Test func handlesMissingAuthors() throws {
        let json = #"{"docs":[{"key":"/works/A","title":"X","cover_i":1}]}"#
        #expect(try CoverSearch.parse(data(json))[0].authors == "")
    }

    @Test func searchURLEncodesTitleAndAuthor() {
        let url = CoverSearch.searchURL(title: "Throne of Glass", author: "Maas").absoluteString
        #expect(url.hasPrefix("https://openlibrary.org/search.json?"))
        #expect(url.contains("title=Throne%20of%20Glass") || url.contains("title=Throne+of+Glass"))
        #expect(url.contains("author=Maas"))
    }

    @Test func searchURLOmitsAuthorWhenNil() {
        let url = CoverSearch.searchURL(title: "Dune", author: nil).absoluteString
        #expect(!url.contains("author="))
    }
}
