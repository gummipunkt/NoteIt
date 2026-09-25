import Foundation

/// What is remembered about a note between sync runs.
public struct SyncEntry: Codable, Equatable, Sendable {
    /// Local file name the Simplenote note is linked to.
    public var fileName: String
    /// Server version at the last successful sync.
    public var version: Int
    /// `Note.contentFingerprint` of the local file at the last successful sync.
    public var fingerprint: String
    /// The part of the Simplenote content before the body (title line plus blank lines),
    /// kept so e.g. a `# ` heading prefix is not lost when the note is pushed back.
    public var header: String

    public init(fileName: String, version: Int, fingerprint: String, header: String) {
        self.fileName = fileName
        self.version = version
        self.fingerprint = fingerprint
        self.header = header
    }
}

public struct SyncState: Codable, Equatable, Sendable {
    /// Simplenote note key → sync entry.
    public var entries: [String: SyncEntry] = [:]

    public init(entries: [String: SyncEntry] = [:]) {
        self.entries = entries
    }

    public static func load(from url: URL) -> SyncState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else { return SyncState() }
        return state
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    func key(forFileName fileName: String) -> String? {
        entries.first { $0.value.fileName == fileName }?.key
    }
}

public struct SyncReport: Equatable, Sendable {
    public var downloaded = 0
    public var uploaded = 0
    public var deletedLocally = 0
    public var deletedRemotely = 0
    public var conflicts = 0
    public var failures: [String] = []

    public init() {}

    public var hasChanges: Bool {
        downloaded + uploaded + deletedLocally + deletedRemotely + conflicts > 0
    }

    public var summary: String {
        var parts: [String] = []
        if downloaded > 0 { parts.append(L10n.tr(.syncReceivedFormat, downloaded)) }
        if uploaded > 0 { parts.append(L10n.tr(.syncSentFormat, uploaded)) }
        if deletedLocally + deletedRemotely > 0 { parts.append(L10n.tr(.syncDeletedFormat, deletedLocally + deletedRemotely)) }
        if conflicts > 0 { parts.append(L10n.tr(.syncConflictsFormat, conflicts)) }
        if !failures.isEmpty { parts.append(L10n.tr(.syncErrorsFormat, failures.count)) }
        return parts.isEmpty ? L10n.tr(.syncUpToDate) : parts.joined(separator: ", ")
    }
}

/// Two-way sync between the local notes folder and Simplenote.
///
/// Mapping: the first line of a Simplenote note is the title (→ file name),
/// the rest is the body (→ file contents).
///
/// Rules per note:
/// - only remote changed → local file is overwritten (and renamed if the title changed)
/// - only local changed → pushed to Simplenote
/// - both changed → local version is pushed relative to the last synced version, so
///   Simperium merges both edits; if that fails a conflict copy is kept locally
/// - deleted locally → moved to the Simplenote trash (unless it was edited remotely)
/// - moved to the Simplenote trash → local file is moved to the Trash (unless edited locally)
public actor SimplenoteSyncEngine {
    public let store: NoteFileStore
    public let stateURL: URL
    private let client: SimperiumClient
    private let makeKey: @Sendable () -> String
    private var state: SyncState

    public init(
        store: NoteFileStore,
        client: SimperiumClient,
        stateURL: URL,
        makeKey: @escaping @Sendable () -> String = { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
    ) {
        self.store = store
        self.client = client
        self.stateURL = stateURL
        self.makeKey = makeKey
        self.state = SyncState.load(from: stateURL)
    }

    public var currentState: SyncState { state }

    /// Keeps the link to Simplenote when a note is renamed inside the app.
    public func noteRenamed(from oldFileName: String, to newFileName: String) {
        guard let key = state.key(forFileName: oldFileName) else { return }
        state.entries[key]?.fileName = newFileName
        try? state.save(to: stateURL)
    }

    /// Forgets all links to Simplenote (e.g. after logging out).
    public func reset() {
        state = SyncState()
        try? FileManager.default.removeItem(at: stateURL)
    }

    // MARK: - Sync

    public func sync() async throws -> SyncReport {
        var report = SyncReport()
        let remoteNotes = try await client.fetchAllNotes()
        let localNotes = try store.loadAll()
        var localByName = Dictionary(localNotes.map { ($0.fileName, $0) }, uniquingKeysWith: { first, _ in first })

        for remote in remoteNotes {
            do {
                try await process(remote: remote, localByName: &localByName, report: &report)
            } catch let error as SimplenoteError where error == .unauthorized {
                throw error
            } catch {
                report.failures.append("\(remote.key): \(error.localizedDescription)")
            }
            try? state.save(to: stateURL)
        }

        // Linked notes whose remote counterpart no longer exists at all (deleted for good).
        let remoteKeys = Set(remoteNotes.map(\.key))
        for key in state.entries.keys where !remoteKeys.contains(key) {
            state.entries[key] = nil
        }

        // Local notes that are not linked yet → create them on Simplenote.
        let linkedFileNames = Set(state.entries.values.map(\.fileName))
        for note in localByName.values.sorted(by: { $0.fileName < $1.fileName }) where !linkedFileNames.contains(note.fileName) {
            do {
                let key = makeKey()
                let content = Self.content(title: note.title, body: note.body, previousHeader: nil)
                let simplenote = SimplenoteNote(
                    content: content,
                    creationDate: note.creationDate,
                    modificationDate: note.modificationDate,
                    markdown: note.isMarkdown
                )
                let saved = try await client.saveNote(key: key, note: simplenote, baseVersion: nil)
                state.entries[key] = SyncEntry(
                    fileName: note.fileName,
                    version: saved.version,
                    fingerprint: note.contentFingerprint,
                    header: Self.split(content: content).header
                )
                report.uploaded += 1
            } catch let error as SimplenoteError where error == .unauthorized {
                throw error
            } catch {
                report.failures.append("\(note.fileName): \(error.localizedDescription)")
            }
            try? state.save(to: stateURL)
        }

        try state.save(to: stateURL)
        return report
    }

    private func process(remote: RemoteNote, localByName: inout [String: Note], report: inout SyncReport) async throws {
        guard let entry = state.entries[remote.key] else {
            // Unknown remote note: download unless it is in the Simplenote trash.
            guard !remote.note.isDeleted else { return }
            let note = try writeNewLocalNote(from: remote)
            localByName[note.fileName] = note
            report.downloaded += 1
            return
        }

        let local = localByName[entry.fileName]
        let remoteChanged = remote.version != entry.version
        let localChanged = local.map { $0.contentFingerprint != entry.fingerprint } ?? false

        if remote.note.isDeleted {
            if let local, localChanged {
                // Edited here but trashed elsewhere: keep the edit and restore the note remotely.
                var restored = remote.note
                restored.isDeleted = false
                try await push(local: local, remote: RemoteNote(key: remote.key, version: remote.version, note: restored),
                               entry: entry, baseVersion: nil, localByName: &localByName)
                report.uploaded += 1
            } else {
                if local != nil {
                    try store.delete(fileName: entry.fileName)
                    localByName[entry.fileName] = nil
                    report.deletedLocally += 1
                }
                state.entries[remote.key] = nil
            }
            return
        }

        guard let local else {
            if remoteChanged {
                // Deleted here, but edited elsewhere: the edit wins, restore the file.
                let note = try writeNewLocalNote(from: remote)
                localByName[note.fileName] = note
                report.downloaded += 1
            } else {
                var trashed = remote.note
                trashed.isDeleted = true
                _ = try await client.saveNote(key: remote.key, note: trashed, baseVersion: nil)
                state.entries[remote.key] = nil
                report.deletedRemotely += 1
            }
            return
        }

        switch (localChanged, remoteChanged) {
        case (false, false):
            return
        case (false, true):
            try applyRemote(remote, to: local, entry: entry, localByName: &localByName)
            report.downloaded += 1
        case (true, false):
            try await push(local: local, remote: remote, entry: entry, baseVersion: entry.version, localByName: &localByName)
            report.uploaded += 1
        case (true, true):
            report.conflicts += 1
            do {
                try await push(local: local, remote: remote, entry: entry, baseVersion: entry.version, localByName: &localByName)
            } catch let error as SimplenoteError where error == .unauthorized {
                throw error
            } catch {
                // The server could not merge: keep our text as a separate note and take theirs.
                let copy = try store.create(title: local.title + L10n.tr(.conflictSuffix), body: local.body, fileExtension: local.fileExtension)
                localByName[copy.fileName] = copy
                try applyRemote(remote, to: local, entry: entry, localByName: &localByName)
            }
        }
    }

    /// Sends the local note to Simplenote and writes the (possibly merged) result back.
    private func push(local: Note, remote: RemoteNote, entry: SyncEntry, baseVersion: Int?, localByName: inout [String: Note]) async throws {
        var outgoing = remote.note
        outgoing.content = Self.content(title: local.title, body: local.body, previousHeader: entry.header)
        outgoing.modificationDate = local.modificationDate
        if local.isMarkdown { outgoing.isMarkdown = true }

        let saved = try await client.saveNote(key: remote.key, note: outgoing, baseVersion: baseVersion)
        if saved.note.content == outgoing.content {
            state.entries[remote.key] = SyncEntry(
                fileName: local.fileName,
                version: saved.version,
                fingerprint: local.contentFingerprint,
                header: Self.split(content: saved.note.content).header
            )
        } else {
            // The server merged in changes from elsewhere.
            try applyRemote(saved, to: local, entry: entry, localByName: &localByName)
        }
    }

    /// Overwrites (and if necessary renames) the local file with the remote content.
    private func applyRemote(_ remote: RemoteNote, to local: Note, entry: SyncEntry, localByName: inout [String: Note]) throws {
        // Do not clobber edits that happened while this sync was running.
        if let current = try? store.load(fileName: local.fileName), current.contentFingerprint != local.contentFingerprint {
            throw SyncConflictError.fileChangedDuringSync(local.fileName)
        }

        let parts = Self.split(content: remote.note.content)
        var fileName = local.fileName
        if parts.title != local.title {
            let renamed = store.uniqueFileName(forTitle: parts.title, fileExtension: local.fileExtension)
            try FileManager.default.moveItem(at: store.fileURL(for: local.fileName), to: store.fileURL(for: renamed))
            localByName[local.fileName] = nil
            fileName = renamed
        }
        let written = try store.write(body: parts.body, toFileName: fileName, modificationDate: remote.note.modificationDate)
        localByName[written.fileName] = written
        state.entries[remote.key] = SyncEntry(
            fileName: written.fileName,
            version: remote.version,
            fingerprint: written.contentFingerprint,
            header: parts.header
        )
    }

    private func writeNewLocalNote(from remote: RemoteNote) throws -> Note {
        let parts = Self.split(content: remote.note.content)
        let fileExtension = remote.note.isMarkdown ? "md" : store.defaultExtension
        let fileName = store.uniqueFileName(forTitle: parts.title, fileExtension: fileExtension)
        let note = try store.write(body: parts.body, toFileName: fileName, modificationDate: remote.note.modificationDate)
        state.entries[remote.key] = SyncEntry(
            fileName: note.fileName,
            version: remote.version,
            fingerprint: note.contentFingerprint,
            header: parts.header
        )
        return note
    }

    // MARK: - Content mapping

    /// Splits Simplenote content into title, body, and the header (everything before the body).
    public static func split(content: String) -> (title: String, body: String, header: String) {
        let withoutLeadingBlankLines = content.drop(while: { $0.isNewline })
        let leading = String(content[..<withoutLeadingBlankLines.startIndex])
        let titleLine = withoutLeadingBlankLines.prefix(while: { !$0.isNewline })
        let rest = withoutLeadingBlankLines[titleLine.endIndex...]
        let body = rest.drop(while: { $0.isNewline })
        let header = leading + String(titleLine) + String(rest[..<body.startIndex])
        return (title(fromTitleLine: String(titleLine)), String(body), header)
    }

    /// Derives a note title from the first line, dropping Markdown heading markers.
    public static func title(fromTitleLine line: String) -> String {
        let withoutHashes = line.trimmingCharacters(in: .whitespaces).drop(while: { $0 == "#" })
        return NoteFileStore.sanitizedTitle(String(withoutHashes))
    }

    /// Builds Simplenote content from a local note, reusing the previous header when the title is unchanged.
    public static func content(title: String, body: String, previousHeader: String?) -> String {
        if let previousHeader, split(content: previousHeader).title == title {
            var header = previousHeader
            if !body.isEmpty, !header.hasSuffix("\n") { header += "\n" }
            return header + body
        }
        return body.isEmpty ? title : title + "\n\n" + body
    }
}

public enum SyncConflictError: Error, LocalizedError {
    case fileChangedDuringSync(String)

    public var errorDescription: String? {
        switch self {
        case .fileChangedDuringSync(let name):
            return L10n.tr(.changedDuringSyncFormat, name)
        }
    }
}
