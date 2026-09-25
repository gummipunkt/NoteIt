import XCTest
@testable import NoteItCore

final class NoteFileStoreTests: XCTestCase {
    var folder: URL!
    var store: NoteFileStore!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("NoteItTests-\(UUID().uuidString)")
        store = NoteFileStore(folder: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        L10n.language = .de
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testCreateAndLoadMarkdownAndText() throws {
        try store.create(title: "Einkauf", body: "- Milch")
        try store.create(title: "Plain", body: "hello", fileExtension: "txt")
        try Data("ignored".utf8).write(to: folder.appendingPathComponent("image.png"))
        try Data("hidden".utf8).write(to: folder.appendingPathComponent(".hidden.md"))

        let notes = try store.loadAll().sorted { $0.fileName < $1.fileName }
        XCTAssertEqual(notes.map(\.fileName), ["Einkauf.md", "Plain.txt"])
        XCTAssertEqual(notes[0].body, "- Milch")
        XCTAssertTrue(notes[0].isMarkdown)
        XCTAssertFalse(notes[1].isMarkdown)
        XCTAssertEqual(notes[1].title, "Plain")
    }

    func testCreateMakesFileNamesUnique() throws {
        let first = try store.create(title: "Idee")
        let second = try store.create(title: "idee")
        let third = try store.create(title: "Idee")
        XCTAssertEqual([first.fileName, second.fileName, third.fileName], ["Idee.md", "idee 2.md", "Idee 3.md"])
    }

    func testSanitizedTitle() {
        XCTAssertEqual(NoteFileStore.sanitizedTitle("a/b:c"), "a-b-c")
        XCTAssertEqual(NoteFileStore.sanitizedTitle("  ..versteckt  "), "versteckt")
        XCTAssertEqual(NoteFileStore.sanitizedTitle("zwei\nZeilen"), "zwei Zeilen")
        XCTAssertEqual(NoteFileStore.sanitizedTitle("   "), "Unbenannt")
    }

    func testSaveRenameDelete() throws {
        var note = try store.create(title: "Alt", body: "eins")
        note.body = "zwei"
        note = try store.save(note)
        XCTAssertEqual(try store.load(fileName: "Alt.md").body, "zwei")

        note = try store.rename(note, to: "Neu")
        XCTAssertEqual(note.fileName, "Neu.md")
        XCTAssertFalse(store.exists(fileName: "Alt.md"))
        XCTAssertEqual(note.body, "zwei")

        try store.create(title: "Belegt")
        XCTAssertThrowsError(try store.rename(note, to: "Belegt")) { error in
            XCTAssertEqual(error as? NoteStoreError, .titleAlreadyExists("Belegt"))
        }

        note = try store.rename(note, to: "NEU")
        XCTAssertEqual(note.fileName, "NEU.md")

        try store.delete(note)
        XCTAssertFalse(store.exists(fileName: "NEU.md"))
    }

    func testReadsBOMAndLatin1() throws {
        try Data([0xEF, 0xBB, 0xBF] + Array("Hallo".utf8)).write(to: folder.appendingPathComponent("bom.txt"))
        try Data([0x47, 0x72, 0xFC, 0xDF, 0x65]).write(to: folder.appendingPathComponent("latin.txt"))
        XCTAssertEqual(try store.load(fileName: "bom.txt").body, "Hallo")
        XCTAssertEqual(try store.load(fileName: "latin.txt").body, "Grüße")
    }

    func testSnippetStripsMarkdown() {
        let note = Note(fileName: "Projektideen.md", body: "# Projektideen\n\n## Diese Woche\n\n- [x] **NoteIt** einrichten\n---\n> Zitat mit [[Link]]\n```\ncode")
        XCTAssertEqual(note.snippet, "Diese Woche NoteIt einrichten Zitat mit Link")
        XCTAssertEqual(Note(fileName: "A.md", body: "1. eins\n| a | b |\n|---|---|").snippet, "eins | a | b |")
    }

    func testSnippetAndFingerprint() {
        let note = Note(fileName: "A.md", body: "\n  Erste Zeile  \n\nZweite\nDritte\nVierte")
        XCTAssertEqual(note.snippet, "Erste Zeile Zweite Dritte")
        XCTAssertEqual(note.contentFingerprint, Note(fileName: "A.txt", body: note.body).contentFingerprint)
        XCTAssertNotEqual(note.contentFingerprint, Note(fileName: "B.md", body: note.body).contentFingerprint)
    }
}
