import XCTest
@testable import NoteItCore

final class NoteSearchTests: XCTestCase {
    let notes = [
        Note(fileName: "Rezept Kuchen.md", body: "Mehl, Zucker, Eier", modificationDate: Date(timeIntervalSince1970: 100)),
        Note(fileName: "Kuchen.md", body: "Lieblingskuchen", modificationDate: Date(timeIntervalSince1970: 50)),
        Note(fileName: "Einkauf.md", body: "Mehl und Kuchenform kaufen", modificationDate: Date(timeIntervalSince1970: 300)),
        Note(fileName: "Kuchenblech.txt", body: "", modificationDate: Date(timeIntervalSince1970: 200)),
        Note(fileName: "Café.md", body: "Öffnungszeiten", modificationDate: Date(timeIntervalSince1970: 10)),
    ]

    func testEmptyQueryReturnsNewestFirst() {
        XCTAssertEqual(NoteSearch.filter(notes, query: "  ").map(\.title),
                       ["Einkauf", "Kuchenblech", "Rezept Kuchen", "Kuchen", "Café"])
    }

    func testRanking() {
        XCTAssertEqual(NoteSearch.filter(notes, query: "kuchen").map(\.title),
                       ["Kuchen", "Kuchenblech", "Rezept Kuchen", "Einkauf"])
    }

    func testAllTermsMustMatch() {
        XCTAssertEqual(NoteSearch.filter(notes, query: "mehl kuchen").map(\.title), ["Einkauf", "Rezept Kuchen"])
        XCTAssertTrue(NoteSearch.filter(notes, query: "mehl banane").isEmpty)
    }

    func testCaseAndDiacriticInsensitive() {
        XCTAssertEqual(NoteSearch.filter(notes, query: "cafe").map(\.title), ["Café"])
        XCTAssertEqual(NoteSearch.filter(notes, query: "OFFNUNG").map(\.title), ["Café"])
    }

    func testExactMatchAndAutoSelection() {
        XCTAssertEqual(NoteSearch.exactTitleMatch(in: notes, query: "KUCHEN ")?.fileName, "Kuchen.md")
        XCTAssertNil(NoteSearch.exactTitleMatch(in: notes, query: "Kuch"))
        XCTAssertEqual(NoteSearch.autoSelection(in: notes, query: "Kuch")?.fileName, "Kuchenblech.txt")
        XCTAssertNil(NoteSearch.autoSelection(in: notes, query: "Mehl"))
        XCTAssertNil(NoteSearch.autoSelection(in: notes, query: ""))
    }
}
