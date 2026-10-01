import XCTest
@testable import NoteItCore

final class TemporaryNotesTests: XCTestCase {
    var root: URL!
    var permanent: NoteFileStore!
    var temporary: NoteFileStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("NoteItTemp-\(UUID().uuidString)")
        permanent = NoteFileStore(folder: root.appendingPathComponent("Notes"))
        temporary = NoteFileStore(folder: TemporaryNotes.folder(in: root), location: .temporary)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testFolderIsOutsideTheNotesFolder() {
        XCTAssertEqual(TemporaryNotes.folder(in: root).path, root.appendingPathComponent("NoteIt/Temporary").path)
    }

    func testStoresStampLocationAndIDsDoNotCollide() throws {
        let a = try permanent.create(title: "Idee")
        let b = try temporary.create(title: "Idee")
        XCTAssertEqual(a.fileName, b.fileName)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertFalse(a.isTemporary)
        XCTAssertTrue(b.isTemporary)
        XCTAssertEqual(try temporary.loadAll().map(\.location), [.temporary])
        XCTAssertEqual(try permanent.loadAll().map(\.location), [.permanent])
    }

    func testMakePermanentMovesFileAndKeepsTitle() throws {
        try permanent.create(title: "Einkauf", body: "alt")
        let scratch = try temporary.create(title: "Einkauf", body: "neu", fileExtension: "txt")

        let moved = try temporary.move(scratch, to: permanent)
        XCTAssertEqual(moved.fileName, "Einkauf 2.txt")
        XCTAssertEqual(moved.body, "neu")
        XCTAssertEqual(moved.location, .permanent)
        XCTAssertTrue(try temporary.loadAll().isEmpty)
        XCTAssertEqual(try permanent.loadAll().count, 2)
    }

    func testExpiry() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let day: TimeInterval = 86_400
        let fresh = Note(fileName: "a.md", body: "", modificationDate: now.addingTimeInterval(-0.5 * day), location: .temporary)
        let old = Note(fileName: "b.md", body: "", modificationDate: now.addingTimeInterval(-8 * day), location: .temporary)
        let permanentNote = Note(fileName: "c.md", body: "", modificationDate: now.addingTimeInterval(-100 * day))

        XCTAssertEqual(TemporaryNotes.daysRemaining(of: fresh, retentionDays: 7, now: now), 6)
        XCTAssertEqual(TemporaryNotes.daysRemaining(of: old, retentionDays: 7, now: now), 0)
        XCTAssertNil(TemporaryNotes.daysRemaining(of: permanentNote, retentionDays: 7, now: now))
        XCTAssertNil(TemporaryNotes.daysRemaining(of: fresh, retentionDays: 0, now: now))

        XCTAssertEqual(TemporaryNotes.expired(in: [fresh, old, permanentNote], retentionDays: 7, now: now).map(\.fileName), ["b.md"])
        XCTAssertTrue(TemporaryNotes.expired(in: [fresh, old], retentionDays: 0, now: now).isEmpty)
        XCTAssertEqual(TemporaryNotes.expired(in: [fresh, old], retentionDays: 1, now: now.addingTimeInterval(day)).count, 2)
    }
}
