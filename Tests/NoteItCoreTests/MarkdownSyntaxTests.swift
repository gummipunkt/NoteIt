import XCTest
@testable import NoteItCore

final class MarkdownSyntaxTests: XCTestCase {
    private func texts(_ kind: MarkdownToken.Kind, in source: String) -> [String] {
        let string = source as NSString
        return MarkdownSyntax.tokens(in: source)
            .filter { $0.kind == kind }
            .sorted { $0.range.location < $1.range.location }
            .map { string.substring(with: $0.range) }
    }

    func testHeadings() {
        let source = "# Eins\ntext\n### Drei\n#kein Titel"
        XCTAssertEqual(texts(.heading(level: 1), in: source), ["# Eins"])
        XCTAssertEqual(texts(.heading(level: 3), in: source), ["### Drei"])
        XCTAssertEqual(texts(.marker, in: source), ["#", "###"])
    }

    func testEmphasis() {
        let source = "Das ist **fett**, *kursiv*, _auch_ und ~~weg~~, aber nicht snake_case_name oder 2 * 3 * 4."
        XCTAssertEqual(texts(.bold, in: source), ["**fett**"])
        XCTAssertEqual(texts(.italic, in: source), ["*kursiv*", "_auch_"])
        XCTAssertEqual(texts(.strikethrough, in: source), ["~~weg~~"])
    }

    func testCodeShieldsContent() {
        let source = "Text `**nicht fett**` und\n```swift\nlet a = **b**\n# kein Titel\n```\n**fett**"
        XCTAssertEqual(texts(.inlineCode, in: source), ["`**nicht fett**`"])
        XCTAssertEqual(texts(.codeBlock, in: source), ["```swift\nlet a = **b**\n# kein Titel\n```\n"])
        XCTAssertEqual(texts(.bold, in: source), ["**fett**"])
        XCTAssertTrue(texts(.heading(level: 1), in: source).isEmpty)
    }

    func testUnclosedFenceRunsToEnd() {
        XCTAssertEqual(texts(.codeBlock, in: "a\n~~~\ncode"), ["~~~\ncode"])
    }

    func testListsTasksQuotesRules() {
        let source = "- eins\n* zwei\n12. zwölf\n- [ ] offen\n- [x] erledigt\n> Zitat\n---\n"
        XCTAssertEqual(texts(.listMarker, in: source), ["-", "*", "12.", "-", "-"])
        XCTAssertEqual(texts(.taskBox(checked: false), in: source), ["[ ]"])
        XCTAssertEqual(texts(.taskBox(checked: true), in: source), ["[x]"])
        XCTAssertEqual(texts(.blockquote, in: source), ["> Zitat"])
        XCTAssertEqual(texts(.horizontalRule, in: source), ["---"])
    }

    func testLinks() {
        let source = "Siehe [[Andere Notiz]], [Apple](https://apple.com/a_b_c) und https://example.com/x_y_z."
        XCTAssertEqual(texts(.wikiLink, in: source), ["[[Andere Notiz]]"])
        XCTAssertEqual(texts(.link, in: source), ["[Apple](https://apple.com/a_b_c)", "https://example.com/x_y_z"])
        XCTAssertTrue(texts(.italic, in: source).isEmpty)
    }

    func testUTF16Ranges() {
        let source = "😀 **fett**"
        XCTAssertEqual(texts(.bold, in: source), ["**fett**"])
    }

    func testWordCount() {
        XCTAssertEqual(MarkdownSyntax.wordCount(of: "# Hallo Welt\n\nDas ist ein Test."), 6)
        XCTAssertEqual(MarkdownSyntax.wordCount(of: ""), 0)
    }
}
