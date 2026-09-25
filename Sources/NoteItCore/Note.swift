import Foundation

/// A single note, backed by one plain text file (`.md` or `.txt`) in the notes folder.
///
/// Like in nvALT, the file name (without extension) is the note title and the
/// file contents are the note body.
public struct Note: Identifiable, Equatable, Hashable, Sendable {
    /// The file name including extension, e.g. `Einkaufsliste.md`. Unique within a folder.
    public var fileName: String
    public var body: String
    public var creationDate: Date
    public var modificationDate: Date

    public var id: String { fileName }

    public init(fileName: String, body: String, creationDate: Date = Date(), modificationDate: Date = Date()) {
        self.fileName = fileName
        self.body = body
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }

    /// The note title, i.e. the file name without its extension.
    public var title: String {
        (fileName as NSString).deletingPathExtension
    }

    /// The lowercase file extension, e.g. `md` or `txt`.
    public var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    /// Whether the note should be treated as Markdown (as opposed to plain text).
    public var isMarkdown: Bool {
        NoteFileStore.markdownExtensions.contains(fileExtension)
    }

    /// A short single-line excerpt of the body for list display.
    public var snippet: String {
        let collapsed = body
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " ")
        return String(collapsed.prefix(200))
    }

    /// A stable fingerprint of the note's title and body, used to detect local changes
    /// between sync runs. (Swift's `hashValue` is randomized per process, so it cannot be used.)
    public var contentFingerprint: String {
        StableHash.fnv1a64(title + "\n" + body)
    }
}

/// Deterministic (non-randomized) string hashing.
public enum StableHash {
    public static func fnv1a64(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
