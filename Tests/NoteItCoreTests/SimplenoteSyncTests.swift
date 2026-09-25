import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import NoteItCore

/// In-memory stand-in for the Simperium HTTP API.
final class FakeSimperium: HTTPTransport, @unchecked Sendable {
    struct Stored {
        var version: Int
        var note: SimplenoteNote
        var history: [Int: SimplenoteNote]
    }

    private let lock = NSLock()
    private var notes: [String: Stored] = [:]
    private(set) var posts: [(key: String, baseVersion: Int?)] = []
    var failMergeWithBaseVersion = false

    func put(_ key: String, content: String, deleted: Bool = false, markdown: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        var note = SimplenoteNote(content: content, creationDate: Date(timeIntervalSince1970: 1), modificationDate: Date(timeIntervalSince1970: 2), markdown: markdown)
        note.isDeleted = deleted
        let version = (notes[key]?.version ?? 0) + 1
        var history = notes[key]?.history ?? [:]
        history[version] = note
        notes[key] = Stored(version: version, note: note, history: history)
    }

    func note(_ key: String) -> (version: Int, note: SimplenoteNote)? {
        lock.lock(); defer { lock.unlock() }
        return notes[key].map { ($0.version, $0.note) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try lock.withLock { try handle(request) }
    }

    private func handle(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        let parts = url.path.split(separator: "/").map(String.init) // 1, app, note, ...
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Simperium-Token"), "token")

        func respond(_ status: Int, _ body: Data = Data(), version: Int? = nil) -> (Data, HTTPURLResponse) {
            var headers: [String: String] = [:]
            if let version { headers["X-Simperium-Version"] = String(version) }
            return (body, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!)
        }

        if parts.count == 4, parts[3] == "index" {
            let index = notes.keys.sorted().map { key -> [String: Any] in
                let stored = notes[key]!
                let data = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(stored.note))
                return ["id": key, "v": stored.version, "d": data]
            }
            return respond(200, try JSONSerialization.data(withJSONObject: ["index": index, "current": "c"]))
        }

        guard parts.count >= 5, parts[3] == "i" else { return respond(404) }
        let key = parts[4]
        if request.httpMethod == "GET" {
            guard let stored = notes[key] else { return respond(404) }
            return respond(200, try JSONEncoder().encode(stored.note), version: stored.version)
        }

        let baseVersion = parts.count == 7 ? Int(parts[6]) : nil
        posts.append((key, baseVersion))
        var incoming = try JSONDecoder().decode(SimplenoteNote.self, from: request.httpBody!)
        if let baseVersion, let stored = notes[key], stored.version != baseVersion {
            if failMergeWithBaseVersion { return respond(409) }
            // Very small "merge": append the server's extra lines that the client did not have.
            let base = stored.history[baseVersion]?.content ?? ""
            let serverAddition = stored.note.content.replacingOccurrences(of: base, with: "")
            incoming.content += serverAddition
        }
        let version = (notes[key]?.version ?? 0) + 1
        var history = notes[key]?.history ?? [:]
        history[version] = incoming
        notes[key] = Stored(version: version, note: incoming, history: history)
        return respond(200, try JSONEncoder().encode(incoming), version: version)
    }
}

final class SimplenoteSyncTests: XCTestCase {
    var folder: URL!
    var store: NoteFileStore!
    var server: FakeSimperium!
    var engine: SimplenoteSyncEngine!
    var keyCounter = 0

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("NoteItSync-\(UUID().uuidString)")
        store = NoteFileStore(folder: folder.appendingPathComponent("notes"))
        server = FakeSimperium()
        engine = makeEngine()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func makeEngine() -> SimplenoteSyncEngine {
        let counter = Counter()
        return SimplenoteSyncEngine(
            store: store,
            client: SimperiumClient(token: "token", transport: server),
            stateURL: folder.appendingPathComponent("state.json"),
            makeKey: { "local\(counter.next())" }
        )
    }

    func testSplitAndContent() {
        let parts = SimplenoteSyncEngine.split(content: "\n# Mein Titel\n\nZeile 1\nZeile 2")
        XCTAssertEqual(parts.title, "Mein Titel")
        XCTAssertEqual(parts.body, "Zeile 1\nZeile 2")
        XCTAssertEqual(parts.header, "\n# Mein Titel\n\n")
        XCTAssertEqual(SimplenoteSyncEngine.content(title: "Mein Titel", body: "neu", previousHeader: parts.header), "\n# Mein Titel\n\nneu")
        XCTAssertEqual(SimplenoteSyncEngine.content(title: "Anders", body: "neu", previousHeader: parts.header), "Anders\n\nneu")
        XCTAssertEqual(SimplenoteSyncEngine.content(title: "Leer", body: "", previousHeader: nil), "Leer")
        XCTAssertEqual(SimplenoteSyncEngine.split(content: "").title, "Unbenannt")
    }

    func testInitialSyncDownloadsAndUploads() async throws {
        server.put("r1", content: "Von Simplenote\n\nInhalt")
        server.put("r2", content: "Im Papierkorb", deleted: true)
        server.put("r3", content: "Nur Text", markdown: false)
        try store.create(title: "Lokal", body: "Hallo")

        let report = try await engine.sync()
        XCTAssertEqual(report.downloaded, 2)
        XCTAssertEqual(report.uploaded, 1)
        XCTAssertEqual(try store.load(fileName: "Von Simplenote.md").body, "Inhalt")
        XCTAssertTrue(store.exists(fileName: "Nur Text.md"), "default extension is md")
        XCTAssertFalse(store.exists(fileName: "Im Papierkorb.md"))
        XCTAssertEqual(server.note("local1")?.note.content, "Lokal\n\nHallo")
        XCTAssertEqual(server.note("local1")?.note.isMarkdown, true)

        let second = try await engine.sync()
        XCTAssertFalse(second.hasChanges, second.summary)
    }

    func testLocalEditIsPushedWithBaseVersion() async throws {
        server.put("r1", content: "# Titel\n\nalt")
        _ = try await engine.sync()

        var note = try store.load(fileName: "Titel.md")
        note.body = "neu"
        try store.save(note)

        let report = try await engine.sync()
        XCTAssertEqual(report.uploaded, 1)
        XCTAssertEqual(server.note("r1")?.note.content, "# Titel\n\nneu", "heading prefix is kept")
        XCTAssertEqual(server.posts.last?.baseVersion, 1)
    }

    func testRemoteEditAndRenameIsApplied() async throws {
        server.put("r1", content: "Alt\n\ntext")
        _ = try await engine.sync()
        server.put("r1", content: "Neu\n\ngeändert")

        let report = try await engine.sync()
        XCTAssertEqual(report.downloaded, 1)
        XCTAssertFalse(store.exists(fileName: "Alt.md"))
        XCTAssertEqual(try store.load(fileName: "Neu.md").body, "geändert")
    }

    func testBothChangedAreMergedByServer() async throws {
        server.put("r1", content: "Liste\n\neins")
        _ = try await engine.sync()
        server.put("r1", content: "Liste\n\neins\nzwei")
        var note = try store.load(fileName: "Liste.md")
        note.body = "null\neins"
        try store.save(note)

        let report = try await engine.sync()
        XCTAssertEqual(report.conflicts, 1)
        XCTAssertEqual(server.note("r1")?.note.content, "Liste\n\nnull\neins\nzwei")
        XCTAssertEqual(try store.load(fileName: "Liste.md").body, "null\neins\nzwei")
        let again = try await engine.sync()
        XCTAssertFalse(again.hasChanges, again.summary)
    }

    func testFailedMergeKeepsConflictCopy() async throws {
        server.put("r1", content: "Liste\n\neins")
        _ = try await engine.sync()
        server.put("r1", content: "Liste\n\nvon dort")
        var note = try store.load(fileName: "Liste.md")
        note.body = "von hier"
        try store.save(note)
        server.failMergeWithBaseVersion = true

        _ = try await engine.sync()
        XCTAssertEqual(try store.load(fileName: "Liste.md").body, "von dort")
        XCTAssertEqual(try store.load(fileName: "Liste (Konflikt).md").body, "von hier")
    }

    func testDeletions() async throws {
        server.put("r1", content: "Lokal gelöscht\n\nx")
        server.put("r2", content: "Remote gelöscht\n\ny")
        _ = try await engine.sync()

        try store.delete(fileName: "Lokal gelöscht.md")
        server.put("r2", content: "Remote gelöscht\n\ny", deleted: true)

        let report = try await engine.sync()
        XCTAssertEqual(report.deletedRemotely, 1)
        XCTAssertEqual(report.deletedLocally, 1)
        XCTAssertEqual(server.note("r1")?.note.isDeleted, true)
        XCTAssertFalse(store.exists(fileName: "Remote gelöscht.md"))
        let state = await engine.currentState
        XCTAssertTrue(state.entries.isEmpty)
    }

    func testRenameInAppKeepsLink() async throws {
        server.put("r1", content: "Vorher\n\nx")
        _ = try await engine.sync()
        let renamed = try store.rename(try store.load(fileName: "Vorher.md"), to: "Nachher")
        await engine.noteRenamed(from: "Vorher.md", to: renamed.fileName)

        _ = try await engine.sync()
        XCTAssertEqual(server.note("r1")?.note.content, "Nachher\n\nx")
        XCTAssertNil(server.note("local1"), "no duplicate note was created")
    }

    func testStatePersistsAcrossEngines() async throws {
        server.put("r1", content: "Dauerhaft\n\nx")
        _ = try await engine.sync()
        engine = makeEngine()
        let report = try await engine.sync()
        XCTAssertFalse(report.hasChanges, report.summary)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}
