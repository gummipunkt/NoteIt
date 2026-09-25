import Foundation

/// nvALT-style incremental search: every whitespace-separated term of the query
/// must appear in the title or the body (case- and diacritic-insensitive).
public enum NoteSearch {
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Filters and orders notes for the given query.
    ///
    /// Ordering: exact title match, then titles starting with the query, then titles
    /// containing all terms, then body-only matches. Within each group the most
    /// recently modified note comes first.
    public static func filter(_ notes: [Note], query: String) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return notes.sorted(by: newestFirst)
        }
        let terms = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)

        return notes
            .compactMap { note -> (Note, Int)? in
                let matchesAll = terms.allSatisfy { term in
                    note.title.range(of: term, options: options) != nil
                        || note.body.range(of: term, options: options) != nil
                }
                guard matchesAll else { return nil }
                return (note, rank(of: note, query: trimmed, terms: terms))
            }
            .sorted { lhs, rhs in
                lhs.1 != rhs.1 ? lhs.1 < rhs.1 : newestFirst(lhs.0, rhs.0)
            }
            .map(\.0)
    }

    /// The note whose title equals the query (ignoring case and diacritics), if any.
    public static func exactTitleMatch(in notes: [Note], query: String) -> Note? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return notes.first { $0.title.compare(trimmed, options: options) == .orderedSame }
    }

    /// The best note to auto-select while typing: exact title match, otherwise the
    /// most recent note whose title starts with the query.
    public static func autoSelection(in notes: [Note], query: String) -> Note? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let exact = exactTitleMatch(in: notes, query: trimmed) { return exact }
        return notes
            .filter { $0.title.range(of: trimmed, options: options.union(.anchored)) != nil }
            .sorted(by: newestFirst)
            .first
    }

    private static func rank(of note: Note, query: String, terms: [String]) -> Int {
        if note.title.compare(query, options: options) == .orderedSame { return 0 }
        if note.title.range(of: query, options: options.union(.anchored)) != nil { return 1 }
        if terms.allSatisfy({ note.title.range(of: $0, options: options) != nil }) { return 2 }
        return 3
    }

    private static func newestFirst(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.modificationDate != rhs.modificationDate { return lhs.modificationDate > rhs.modificationDate }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}
