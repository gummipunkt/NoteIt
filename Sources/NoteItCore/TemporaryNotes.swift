import Foundation

/// Rules for temporary notes: they live outside the synced notes folder and are
/// cleaned up after a number of days without changes.
public enum TemporaryNotes {
    /// Retention choices offered in Settings (0 = keep forever).
    public static let retentionChoices = [0, 1, 7, 30]
    public static let defaultRetentionDays = 7

    /// Where temporary notes are kept: next to NoteIt's other local data, never in the notes folder.
    public static func folder(in applicationSupport: URL) -> URL {
        applicationSupport
            .appendingPathComponent("NoteIt", isDirectory: true)
            .appendingPathComponent("Temporary", isDirectory: true)
    }

    /// When the note will be cleaned up, or `nil` if temporary notes are kept forever.
    public static func expiryDate(of note: Note, retentionDays: Int) -> Date? {
        guard note.isTemporary, retentionDays > 0 else { return nil }
        return note.modificationDate.addingTimeInterval(TimeInterval(retentionDays) * 86_400)
    }

    /// Whole days left until cleanup (0 = today), or `nil` if the note does not expire.
    public static func daysRemaining(of note: Note, retentionDays: Int, now: Date = Date()) -> Int? {
        guard let expiry = expiryDate(of: note, retentionDays: retentionDays) else { return nil }
        let seconds = expiry.timeIntervalSince(now)
        return seconds <= 0 ? 0 : Int(seconds / 86_400)
    }

    /// Temporary notes whose retention time has passed.
    public static func expired(in notes: [Note], retentionDays: Int, now: Date = Date()) -> [Note] {
        notes.filter { note in
            guard let expiry = expiryDate(of: note, retentionDays: retentionDays) else { return false }
            return expiry <= now
        }
    }
}
