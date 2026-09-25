import Foundation

/// A `[[Target]]` or `[[Target|Label]]` reference to another note.
public struct WikiLink: Equatable, Sendable {
    public var target: String
    public var label: String
    /// Range of the full `[[…]]` construct in the source string.
    public var range: Range<String.Index>

    public init(target: String, label: String, range: Range<String.Index>) {
        self.target = target
        self.label = label
        self.range = range
    }
}

public enum WikiLinks {
    /// URL scheme used for links in the Markdown preview.
    public static let scheme = "noteit"
    static let existingHost = "note"
    static let missingHost = "new"

    /// Finds all wiki links in plain text (does not skip code; see `markdownWithLinks` for that).
    public static func links(in text: String) -> [WikiLink] {
        var result: [WikiLink] = []
        var searchStart = text.startIndex
        while let open = text.range(of: "[[", range: searchStart..<text.endIndex) {
            guard let close = text.range(of: "]]", range: open.upperBound..<text.endIndex) else { break }
            let inner = text[open.upperBound..<close.lowerBound]
            if inner.contains("\n") || inner.contains("[") {
                // Not a valid link; continue right after this "[[" so nested cases like "[[[[x]]" still work.
                searchStart = text.index(after: open.lowerBound)
                continue
            }
            let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let target = parts[0].trimmingCharacters(in: .whitespaces)
            let label = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : target
            if !target.isEmpty {
                result.append(WikiLink(target: target, label: label.isEmpty ? target : label, range: open.lowerBound..<close.upperBound))
            }
            searchStart = close.upperBound
        }
        return result
    }

    /// Builds the preview URL for a link target.
    public static func url(forTarget target: String, exists: Bool) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = exists ? existingHost : missingHost
        components.path = "/" + target
        return components.url!
    }

    /// Extracts the note title from a preview link URL, or `nil` if it is not a wiki link.
    public static func target(from url: URL) -> String? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == existingHost || components.host == missingHost else { return nil }
        let path = components.path
        let target = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return target.isEmpty ? nil : target
    }

    /// Replaces wiki links with regular Markdown links (`noteit://note/Title` for existing
    /// notes, `noteit://new/Title` for missing ones). Fenced code blocks and inline code
    /// spans are left untouched.
    public static func markdownWithLinks(_ markdown: String, noteExists: (String) -> Bool) -> String {
        var output = ""
        var fence: String?

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            let trimmed = line.drop(while: { $0 == " " })
            if let currentFence = fence {
                if trimmed.hasPrefix(currentFence) { fence = nil }
                output += line
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = trimmed.first!
                fence = String(trimmed.prefix(while: { $0 == marker }))
                output += line
            } else if line.hasPrefix("    ") || line.hasPrefix("\t") {
                // Indented code block (or list continuation). Leave it alone to be safe.
                output += line
            } else {
                output += replaceOutsideInlineCode(String(line), noteExists: noteExists)
            }
            if index < lines.count - 1 { output += "\n" }
        }
        return output
    }

    private static func replaceOutsideInlineCode(_ line: String, noteExists: (String) -> Bool) -> String {
        guard line.contains("[[") else { return line }
        var result = ""
        var rest = Substring(line)
        while let tick = rest.firstIndex(of: "`") {
            result += replaceLinks(in: String(rest[..<tick]), noteExists: noteExists)
            // Code span: a run of N backticks is closed by the next run of exactly N backticks.
            let run = rest[tick...].prefix(while: { $0 == "`" })
            let afterRun = rest[run.endIndex...]
            if let close = afterRun.range(of: String(run)) {
                result += rest[tick..<close.upperBound]
                rest = rest[close.upperBound...]
            } else {
                result += run
                rest = afterRun
            }
        }
        result += replaceLinks(in: String(rest), noteExists: noteExists)
        return result
    }

    private static func replaceLinks(in text: String, noteExists: (String) -> Bool) -> String {
        let found = links(in: text)
        guard !found.isEmpty else { return text }
        var result = ""
        var cursor = text.startIndex
        for link in found {
            result += text[cursor..<link.range.lowerBound]
            let url = url(forTarget: link.target, exists: noteExists(link.target))
            result += "[\(escapeLinkText(link.label))](<\(url.absoluteString)>)"
            cursor = link.range.upperBound
        }
        result += text[cursor...]
        return result
    }

    private static func escapeLinkText(_ text: String) -> String {
        var escaped = ""
        for character in text {
            if "\\[]*_`<>".contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
        return escaped
    }
}
