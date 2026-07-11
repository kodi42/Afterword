import Testing
import Foundation
@testable import Afterword

/// Port of the RN `tests/coverSearch.test.ts` — validates Apple Books + Open
/// Library response parsing and URL building (all pure, no network).
struct CoverSearchTests {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - Apple Books

    @Test func appleReturnsEmptyForNoResults() throws {
        #expect(try CoverSearch.parseAppleBooks(data(#"{"results":[]}"#)).isEmpty)
        #expect(try CoverSearch.parseAppleBooks(data(#"{}"#)).isEmpty)
    }

    @Test func appleMapsResultsToHiResArtwork() throws {
        let json = #"""
        {"results":[{"trackId":42,"trackName":"Throne of Glass","artistName":"Sarah J. Maas","artworkUrl100":"https://is1.mzstatic.com/image/thumb/abc/100x100bb.jpg"}]}
        """#
        let results = try CoverSearch.parseAppleBooks(data(json))
        #expect(results.count == 1)
        #expect(results[0].id == "apple-42")
        #expect(results[0].title == "Throne of Glass")
        #expect(results[0].authors == "Sarah J. Maas")
        // 100x100 is rewritten to a crisp 600x600 render.
        #expect(results[0].thumbnailURL.absoluteString == "https://is1.mzstatic.com/image/thumb/abc/600x600bb.jpg")
    }

    @Test func appleSkipsResultsWithoutArtwork() throws {
        let json = #"""
        {"results":[{"trackId":1,"trackName":"No Art"},{"trackId":2,"trackName":"Has Art","artworkUrl100":"https://x/100x100bb.jpg"}]}
        """#
        let results = try CoverSearch.parseAppleBooks(data(json))
        #expect(results.count == 1)
        #expect(results[0].id == "apple-2")
    }

    @Test func appleDedupesRepeatedTrackIDs() throws {
        let json = #"""
        {"results":[{"trackId":7,"artworkUrl100":"https://x/100x100bb.jpg"},{"trackId":7,"artworkUrl100":"https://y/100x100bb.jpg"}]}
        """#
        #expect(try CoverSearch.parseAppleBooks(data(json)).count == 1)
    }

    @Test func appleHandlesMissingAuthor() throws {
        let json = #"{"results":[{"trackId":1,"trackName":"X","artworkUrl100":"https://x/100x100bb.jpg"}]}"#
        #expect(try CoverSearch.parseAppleBooks(data(json))[0].authors == "")
    }

    @Test func appleSearchURLBuildsEbookTermQuery() {
        let url = CoverSearch.appleSearchURL(title: "Throne of Glass", author: "Maas").absoluteString
        #expect(url.hasPrefix("https://itunes.apple.com/search?"))
        #expect(url.contains("media=ebook"))
        #expect(url.contains("term=Throne%20of%20Glass%20Maas") || url.contains("term=Throne+of+Glass+Maas"))
    }

    @Test func appleSearchURLOmitsAuthorWhenNil() {
        let url = CoverSearch.appleSearchURL(title: "Dune", author: nil).absoluteString
        #expect(url.contains("term=Dune"))
        #expect(!url.contains("Dune%20"))
    }

    // MARK: - Open Library

    @Test func openLibraryReturnsEmptyForEmptyDocs() throws {
        #expect(try CoverSearch.parseOpenLibrary(data(#"{"docs":[]}"#)).isEmpty)
        #expect(try CoverSearch.parseOpenLibrary(data(#"{}"#)).isEmpty)
    }

    @Test func openLibraryMapsDocsToCoverURLs() throws {
        let json = #"""
        {"docs":[{"key":"/works/OL1W","title":"Throne of Glass","author_name":["Sarah J. Maas"],"cover_i":13312488}]}
        """#
        let results = try CoverSearch.parseOpenLibrary(data(json))
        #expect(results.count == 1)
        #expect(results[0].id == "/works/OL1W")
        #expect(results[0].title == "Throne of Glass")
        #expect(results[0].authors == "Sarah J. Maas")
        #expect(results[0].thumbnailURL.absoluteString == "https://covers.openlibrary.org/b/id/13312488-M.jpg")
    }

    @Test func openLibrarySkipsDocsWithoutCover() throws {
        let json = #"""
        {"docs":[{"key":"/works/A","title":"No Cover"},{"key":"/works/B","title":"Has Cover","cover_i":42}]}
        """#
        let results = try CoverSearch.parseOpenLibrary(data(json))
        #expect(results.count == 1)
        #expect(results[0].id == "/works/B")
    }

    @Test func openLibraryDedupesRepeatedCoverIDs() throws {
        let json = #"{"docs":[{"key":"/works/A","cover_i":7},{"key":"/works/B","cover_i":7}]}"#
        #expect(try CoverSearch.parseOpenLibrary(data(json)).count == 1)
    }

    @Test func openLibraryHandlesMissingAuthors() throws {
        let json = #"{"docs":[{"key":"/works/A","title":"X","cover_i":1}]}"#
        #expect(try CoverSearch.parseOpenLibrary(data(json))[0].authors == "")
    }

    @Test func openLibrarySearchURLEncodesTitleAndAuthor() {
        let url = CoverSearch.openLibrarySearchURL(title: "Throne of Glass", author: "Maas").absoluteString
        #expect(url.hasPrefix("https://openlibrary.org/search.json?"))
        #expect(url.contains("title=Throne%20of%20Glass") || url.contains("title=Throne+of+Glass"))
        #expect(url.contains("author=Maas"))
    }

    @Test func openLibrarySearchURLOmitsAuthorWhenNil() {
        let url = CoverSearch.openLibrarySearchURL(title: "Dune", author: nil).absoluteString
        #expect(!url.contains("author="))
    }
}
