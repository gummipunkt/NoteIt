import XCTest
@testable import NoteItCore

final class WikiLinksAndMarkdownTests: XCTestCase {
    func testFindsLinks() {
        let links = WikiLinks.links(in: "Siehe [[Einkauf]] und [[Rezept Kuchen|das Rezept]], nicht [[ ]] oder [[kaputt\n]]")
        XCTAssertEqual(links.map(\.target), ["Einkauf", "Rezept Kuchen"])
        XCTAssertEqual(links.map(\.label), ["Einkauf", "das Rezept"])
    }

    func testURLRoundTrip() {
        let url = WikiLinks.url(forTarget: "Rezept Kuchen?#1", exists: true)
        XCTAssertTrue(url.absoluteString.hasPrefix("noteit://note/"))
        XCTAssertEqual(WikiLinks.target(from: url), "Rezept Kuchen?#1")
        XCTAssertTrue(WikiLinks.url(forTarget: "X", exists: false).absoluteString.hasPrefix("noteit://new/"))
        XCTAssertNil(WikiLinks.target(from: URL(string: "https://example.com/X")!))
    }

    func testMarkdownConversionSkipsCode() {
        let markdown = """
        Link [[A]] und `[[B]]` und ``x [[C]] ` y``.
        ```
        [[D]]
        ```
            [[E]]
        Ende [[F|f_1]]
        """
        let converted = WikiLinks.markdownWithLinks(markdown) { $0 == "A" }
        XCTAssertTrue(converted.contains("[A](<noteit://note/A>)"))
        XCTAssertTrue(converted.contains("`[[B]]`"))
        XCTAssertTrue(converted.contains("``x [[C]] ` y``"))
        XCTAssertTrue(converted.contains("\n[[D]]\n"))
        XCTAssertTrue(converted.contains("    [[E]]"))
        XCTAssertTrue(converted.contains("[f\\_1](<noteit://new/F>)"))
    }

    func testHTMLRendering() {
        let note = Note(fileName: "Test.md", body: "# Titel\n\nText mit **fett** und [[Andere Notiz]].\n\n| a | b |\n|---|---|\n| 1 | 2 |\n")
        let html = MarkdownRenderer.htmlDocument(for: note) { _ in true }
        XCTAssertTrue(html.contains("<h1>Titel</h1>"), html)
        XCTAssertTrue(html.contains("<strong>fett</strong>"), html)
        XCTAssertTrue(html.contains("href=\"noteit://note/Andere%20Notiz\""), html)
        XCTAssertTrue(html.contains("<table>"), html)
    }

    func testPlainTextRendering() {
        let note = Note(fileName: "Test.txt", body: "<b>kein html</b> [[Ziel]]")
        let html = MarkdownRenderer.htmlDocument(for: note) { _ in false }
        XCTAssertTrue(html.contains("&lt;b&gt;kein html&lt;/b&gt; <a href=\"noteit://new/Ziel\">Ziel</a>"), html)
    }
}
