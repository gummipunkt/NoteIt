import Foundation

public enum NoteStoreError: Error, LocalizedError, Equatable {
    case noteNotFound(String)
    case titleAlreadyExists(String)
    case unreadableFile(String)

    public var errorDescription: String? {
        switch self {
        case .noteNotFound(let name):
            return L10n.tr(.noteNotFoundFormat, name)
        case .titleAlreadyExists(let title):
            return L10n.tr(.titleExistsFormat, title)
        case .unreadableFile(let name):
            return L10n.tr(.unreadableFileFormat, name)
        }
    }
}

/// Reads and writes notes as plain `.md` / `.txt` files in a single folder.
///
/// Keeping notes as ordinary files is what makes syncing via Dropbox or
/// Google Drive work: point the store at a folder inside the synced directory
/// and the respective desktop client takes care of the rest.
public struct NoteFileStore: Sendable {
    public static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]
    public static let textExtensions: Set<String> = ["txt", "text"]
    public static var supportedExtensions: Set<String> { markdownExtensions.union(textExtensions) }

    public let folder: URL
    /// Extension used for newly created notes (`md` or `txt`).
    public var defaultExtension: String

    public init(folder: URL, defaultExtension: String = "md") {
        self.folder = folder
        self.defaultExtension = defaultExtension
    }

    // MARK: - Reading

    /// Loads all notes in the folder. Hidden files, subfolders and unsupported files are ignored.
    public func loadAll() throws -> [Note] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .compactMap { try? loadNote(at: $0) }
    }

    public func load(fileName: String) throws -> Note {
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NoteStoreError.noteNotFound(fileName)
        }
        return try loadNote(at: url)
    }

    public func exists(fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
    }

    public func fileURL(for fileName: String) -> URL {
        folder.appendingPathComponent(fileName, isDirectory: false)
    }

    private func loadNote(at url: URL) throws -> Note {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .creationDateKey])
        guard values.isRegularFile ?? false else { throw NoteStoreError.unreadableFile(url.lastPathComponent) }
        let data = try Data(contentsOf: url)
        guard let body = Self.decode(data) else { throw NoteStoreError.unreadableFile(url.lastPathComponent) }
        let modified = values.contentModificationDate ?? Date()
        return Note(
            fileName: url.lastPathComponent,
            body: body,
            creationDate: values.creationDate ?? modified,
            modificationDate: modified
        )
    }

    static func decode(_ data: Data) -> String? {
        if let string = String(data: data, encoding: .utf8) {
            // Drop a UTF-8 byte order mark if present.
            return string.hasPrefix("\u{FEFF}") ? String(string.dropFirst()) : string
        }
        // UTF-16 only with a byte order mark; otherwise almost any byte sequence would "decode".
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let string = String(data: data, encoding: .utf16) {
            return string
        }
        // Legacy 8-bit files (e.g. older Windows or nvALT notes).
        return String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1)
    }

    // MARK: - Writing

    /// Creates a new note file. If a note with that title already exists, a number is appended.
    @discardableResult
    public func create(title: String, body: String = "", fileExtension: String? = nil) throws -> Note {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileName = uniqueFileName(forTitle: title, fileExtension: fileExtension ?? defaultExtension)
        return try write(body: body, toFileName: fileName)
    }

    /// Writes the note body to disk (atomically) and returns the note with updated dates.
    @discardableResult
    public func save(_ note: Note) throws -> Note {
        try write(body: note.body, toFileName: note.fileName)
    }

    @discardableResult
    public func write(body: String, toFileName fileName: String, modificationDate: Date? = nil) throws -> Note {
        let url = fileURL(for: fileName)
        try Data(body.utf8).write(to: url, options: .atomic)
        if let modificationDate {
            try? FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: url.path)
        }
        return try loadNote(at: url)
    }

    /// Renames a note (changes its title). Keeps the file extension.
    @discardableResult
    public func rename(_ note: Note, to newTitle: String) throws -> Note {
        let sanitized = Self.sanitizedTitle(newTitle)
        let newFileName = sanitized + "." + (note.fileExtension.isEmpty ? defaultExtension : note.fileExtension)
        if newFileName == note.fileName { return note }

        let source = fileURL(for: note.fileName)
        let destination = fileURL(for: newFileName)
        let differsOnlyInCase = newFileName.lowercased() == note.fileName.lowercased()
        if !differsOnlyInCase, FileManager.default.fileExists(atPath: destination.path) {
            throw NoteStoreError.titleAlreadyExists(sanitized)
        }
        if differsOnlyInCase {
            // Case-insensitive file systems (APFS default) need a detour for pure case changes.
            let temporary = fileURL(for: UUID().uuidString + ".tmp")
            try FileManager.default.moveItem(at: source, to: temporary)
            try FileManager.default.moveItem(at: temporary, to: destination)
        } else {
            try FileManager.default.moveItem(at: source, to: destination)
        }
        return try loadNote(at: destination)
    }

    /// Deletes a note. On macOS the file is moved to the Trash so it can be recovered.
    public func delete(_ note: Note) throws {
        try delete(fileName: note.fileName)
    }

    public func delete(fileName: String) throws {
        let url = fileURL(for: fileName)
        #if os(macOS)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        #else
        try FileManager.default.removeItem(at: url)
        #endif
    }

    // MARK: - File names

    /// Returns a file name for the title that does not collide with an existing file,
    /// e.g. `Idee.md`, `Idee 2.md`, `Idee 3.md`, …
    public func uniqueFileName(forTitle title: String, fileExtension: String) -> String {
        let base = Self.sanitizedTitle(title)
        let existing = Set(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).map { $0.lowercased() })
        var candidate = base + "." + fileExtension
        var counter = 2
        while existing.contains(candidate.lowercased()) {
            candidate = "\(base) \(counter).\(fileExtension)"
            counter += 1
        }
        return candidate
    }

    /// Turns an arbitrary title into something that is safe to use as a file name.
    public static func sanitizedTitle(_ title: String) -> String {
        var result = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .components(separatedBy: .newlines).joined(separator: " ")
            .components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespaces)
        while result.hasPrefix(".") { result.removeFirst() }
        if result.count > 200 { result = String(result.prefix(200)).trimmingCharacters(in: .whitespaces) }
        return result.isEmpty ? L10n.tr(.untitled) : result
    }
}
