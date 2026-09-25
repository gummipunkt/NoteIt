import Foundation

/// A syntax element found in Markdown source, used for highlighting in the editor.
public struct MarkdownToken: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// A whole heading line.
        case heading(level: Int)
        /// Syntax characters that should be de-emphasized (`#`, `**`, `>` …).
        case marker
        case bold
        case italic
        case strikethrough
        case inlineCode
        case codeBlock
        case blockquote
        case listMarker
        case taskBox(checked: Bool)
        case link
        case wikiLink
        case horizontalRule
    }

    public var kind: Kind
    /// UTF-16 range, directly usable with `NSString` / `NSTextStorage`.
    public var range: NSRange

    public init(kind: Kind, range: NSRange) {
        self.kind = kind
        self.range = range
    }
}

/// A small, fast, line-oriented Markdown scanner for editor highlighting.
/// It is deliberately forgiving; the preview uses a real CommonMark parser.
public enum MarkdownSyntax {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static let heading = regex(#"^(#{1,6})[ \t]+.*$"#)
    private static let blockquote = regex(#"^[ \t]*(>+).*$"#)
    private static let horizontalRule = regex(#"^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)
    private static let listMarker = regex(#"^[ \t]*([-*+]|\d{1,9}[.)])[ \t]+"#)
    private static let taskBox = regex(#"^[ \t]*[-*+][ \t]+(\[[ xX]\])(?=[ \t])"#)
    private static let inlineCode = regex(#"(`+)[^`\n]+?\1"#)
    private static let bold = regex(#"(\*\*|__)(?=\S)[^\n]+?(?<=\S)\1"#)
    private static let italic = regex(#"(?<![*_\w\\])([*_])(?=[^\s*_])[^\n*_]*?(?<=[^\s*_\\])\1(?![*_\w])"#)
    private static let strikethrough = regex(#"~~(?=\S)[^\n]+?(?<=\S)~~"#)
    private static let wikiLink = regex(#"\[\[[^\[\]\n]+\]\]"#)
    private static let link = regex(#"!?\[[^\]\n]*\]\([^)\n]*\)|<https?://[^>\s]+>|https?://[^\s<>()\[\]]+[^\s<>()\[\].,;:!?'"]"#)

    public static func tokens(in text: String) -> [MarkdownToken] {
        let string = text as NSString
        var tokens: [MarkdownToken] = []

        // 1. Fenced code blocks. Everything inside them is excluded from other rules.
        let codeBlocks = fencedCodeBlocks(in: string)
        tokens += codeBlocks.map { MarkdownToken(kind: .codeBlock, range: $0) }
        var excluded = codeBlocks

        func matches(_ expression: NSRegularExpression) -> [NSTextCheckingResult] {
            expression.matches(in: text, range: NSRange(location: 0, length: string.length))
                .filter { match in !excluded.contains { NSIntersectionRange($0, match.range).length > 0 } }
        }

        // 2. Inline code spans, which also shield their content.
        let codeSpans = matches(inlineCode).map(\.range)
        tokens += codeSpans.map { MarkdownToken(kind: .inlineCode, range: $0) }
        excluded += codeSpans

        // 3. Block-level elements.
        for match in matches(heading) {
            let marker = match.range(at: 1)
            tokens.append(MarkdownToken(kind: .heading(level: marker.length), range: match.range))
            tokens.append(MarkdownToken(kind: .marker, range: marker))
        }
        let rules = matches(horizontalRule).map(\.range)
        tokens += rules.map { MarkdownToken(kind: .horizontalRule, range: $0) }
        for match in matches(blockquote) {
            tokens.append(MarkdownToken(kind: .blockquote, range: match.range))
            tokens.append(MarkdownToken(kind: .marker, range: match.range(at: 1)))
        }
        for match in matches(listMarker) where !rules.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
            tokens.append(MarkdownToken(kind: .listMarker, range: match.range(at: 1)))
        }
        for match in matches(taskBox) {
            let box = match.range(at: 1)
            let checked = string.substring(with: box).lowercased() == "[x]"
            tokens.append(MarkdownToken(kind: .taskBox(checked: checked), range: box))
        }

        // 4. Links (before emphasis, so underscores in URLs are not italicized).
        let wikiLinks = matches(wikiLink).map(\.range)
        tokens += wikiLinks.map { MarkdownToken(kind: .wikiLink, range: $0) }
        excluded += wikiLinks
        let links = matches(link).map(\.range)
        tokens += links.map { MarkdownToken(kind: .link, range: $0) }
        excluded += links

        // 5. Inline emphasis.
        for match in matches(bold) {
            tokens.append(MarkdownToken(kind: .bold, range: match.range))
            tokens += delimiterMarkers(for: match.range, length: 2)
        }
        for match in matches(italic) {
            tokens.append(MarkdownToken(kind: .italic, range: match.range))
            tokens += delimiterMarkers(for: match.range, length: 1)
        }
        for match in matches(strikethrough) {
            tokens.append(MarkdownToken(kind: .strikethrough, range: match.range))
            tokens += delimiterMarkers(for: match.range, length: 2)
        }
        return tokens
    }

    private static func delimiterMarkers(for range: NSRange, length: Int) -> [MarkdownToken] {
        guard range.length >= length * 2 else { return [] }
        return [
            MarkdownToken(kind: .marker, range: NSRange(location: range.location, length: length)),
            MarkdownToken(kind: .marker, range: NSRange(location: NSMaxRange(range) - length, length: length)),
        ]
    }

    /// Ranges of ``` / ~~~ fenced code blocks, including the fence lines.
    /// An unclosed fence runs to the end of the text (as in CommonMark).
    static func fencedCodeBlocks(in string: NSString) -> [NSRange] {
        var blocks: [NSRange] = []
        var openFence: (marker: String, start: Int)?
        var location = 0
        while location < string.length {
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            let line = string.substring(with: lineRange)
            let trimmed = line.drop(while: { $0 == " " })
            if let fence = openFence {
                if trimmed.hasPrefix(fence.marker),
                   trimmed.drop(while: { String($0) == String(fence.marker.first!) }).allSatisfy(\.isWhitespace) {
                    blocks.append(NSRange(location: fence.start, length: NSMaxRange(lineRange) - fence.start))
                    openFence = nil
                }
            } else if let first = trimmed.first, first == "`" || first == "~" {
                let run = trimmed.prefix(while: { $0 == first })
                if run.count >= 3 {
                    openFence = (String(run), lineRange.location)
                }
            }
            location = NSMaxRange(lineRange)
        }
        if let fence = openFence {
            blocks.append(NSRange(location: fence.start, length: string.length - fence.start))
        }
        return blocks
    }

    /// Word count as shown in the editor footer.
    public static func wordCount(of text: String) -> Int {
        // Whitespace-separated chunks that contain at least one letter or digit
        // (so "#", "-" or "—" are not counted). Portable to Linux, unlike `.byWords`.
        text.split(whereSeparator: { $0.isWhitespace })
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }
}
