import Foundation
import Markdown

/// Turns a note into a complete HTML page for the preview pane.
public enum MarkdownRenderer {
    /// Renders the Markdown body (including wiki links) to an HTML fragment.
    public static func htmlFragment(markdown: String, noteExists: (String) -> Bool) -> String {
        let linked = WikiLinks.markdownWithLinks(markdown, noteExists: noteExists)
        return HTMLFormatter.format(linked)
    }

    /// Renders a full HTML document. Plain text notes (`.txt`) are shown preformatted,
    /// but wiki links in them are still clickable.
    /// - Parameter accentColor: CSS color used for links and accents (e.g. the macOS accent color).
    public static func htmlDocument(for note: Note, noteExists: (String) -> Bool, accentColor: String? = nil) -> String {
        let content = htmlBody(for: note, noteExists: noteExists)
        let accentCSS = accentColor.map { ":root { --accent: \($0); }" } ?? ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapeHTML(note.title))</title>
        <style>\(stylesheet)\(accentCSS)</style>
        </head>
        <body>
        \(content)
        </body>
        </html>
        """
    }

    /// The inner HTML of the `<body>` element, used to update an already loaded preview in place.
    public static func htmlBody(for note: Note, noteExists: (String) -> Bool) -> String {
        if note.isMarkdown {
            return htmlFragment(markdown: note.body, noteExists: noteExists)
        }
        return "<pre class=\"plain\">" + plainTextWithLinks(note.body, noteExists: noteExists) + "</pre>"
    }

    static func plainTextWithLinks(_ text: String, noteExists: (String) -> Bool) -> String {
        var result = ""
        var cursor = text.startIndex
        for link in WikiLinks.links(in: text) {
            result += escapeHTML(String(text[cursor..<link.range.lowerBound]))
            let url = WikiLinks.url(forTarget: link.target, exists: noteExists(link.target))
            result += "<a href=\"\(escapeHTML(url.absoluteString))\">\(escapeHTML(link.label))</a>"
            cursor = link.range.upperBound
        }
        result += escapeHTML(String(text[cursor...]))
        return result
    }

    public static func escapeHTML(_ string: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    static let stylesheet = """
    :root {
      color-scheme: light dark;
      --text: #1d1d1f; --muted: #6e6e73; --faint: #aeaeb2; --bg: #ffffff;
      --code-bg: rgba(0, 0, 0, 0.045); --border: rgba(0, 0, 0, 0.1);
      --accent: #007aff; --missing: #d4432e; --mark: rgba(255, 214, 10, 0.45);
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --text: #ececf0; --muted: #a1a1a6; --faint: #636366; --bg: #1e1e1e;
        --code-bg: rgba(255, 255, 255, 0.07); --border: rgba(255, 255, 255, 0.12);
        --accent: #0a84ff; --missing: #ff7a66; --mark: rgba(255, 214, 10, 0.3);
      }
    }
    html { background: var(--bg); }
    body {
      font: 16px/1.68 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
      color: var(--text); background: var(--bg);
      max-width: 44em; margin: 0 auto; padding: 8px 32px 64px;
      word-wrap: break-word; -webkit-font-smoothing: antialiased;
    }
    ::selection { background: color-mix(in srgb, var(--accent) 28%, transparent); }
    h1, h2, h3, h4, h5, h6 {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
      line-height: 1.22; letter-spacing: -0.015em; margin: 1.6em 0 0.55em; font-weight: 700;
    }
    h1 { font-size: 1.9em; letter-spacing: -0.025em; }
    h2 { font-size: 1.45em; padding-bottom: 0.25em; border-bottom: 1px solid var(--border); }
    h3 { font-size: 1.2em; }
    h4, h5, h6 { font-size: 1em; color: var(--muted); }
    body > :first-child { margin-top: 0.4em; }
    p, ul, ol, blockquote, pre, table { margin: 0 0 1em; }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; text-underline-offset: 3px; }
    a[href^="noteit://note/"] {
      background: color-mix(in srgb, var(--accent) 10%, transparent);
      border-radius: 4px; padding: 0 3px;
    }
    a[href^="noteit://new/"] {
      color: var(--missing); border-bottom: 1px dashed currentColor;
    }
    strong { font-weight: 650; }
    mark { background: var(--mark); color: inherit; border-radius: 3px; padding: 0 2px; }
    code, pre { font: 0.88em/1.55 ui-monospace, "SF Mono", Menlo, monospace; }
    code { background: var(--code-bg); padding: 0.12em 0.38em; border-radius: 5px; }
    pre {
      background: var(--code-bg); padding: 14px 16px; border-radius: 10px;
      overflow-x: auto; border: 1px solid var(--border);
    }
    pre code { background: none; padding: 0; font-size: 1em; }
    pre.plain {
      background: none; border: none; padding: 0; white-space: pre-wrap;
      font: 15px/1.6 ui-monospace, "SF Mono", Menlo, monospace;
    }
    blockquote {
      padding: 0.2em 1.1em; color: var(--muted);
      border-left: 3px solid var(--accent);
      background: color-mix(in srgb, var(--accent) 5%, transparent);
      border-radius: 0 8px 8px 0;
    }
    blockquote p:last-child { margin-bottom: 0; }
    ul, ol { padding-left: 1.5em; }
    li { margin: 0.25em 0; }
    li::marker { color: var(--accent); }
    li > p { margin: 0.2em 0; }
    input[type=checkbox] { accent-color: var(--accent); margin: 0 0.45em 0 -1.3em; transform: translateY(1px); }
    li:has(> input[type=checkbox]) { list-style: none; }
    table { border-collapse: separate; border-spacing: 0; border: 1px solid var(--border); border-radius: 10px; overflow: hidden; }
    th, td { padding: 0.5em 0.85em; border-bottom: 1px solid var(--border); text-align: left; }
    tr:last-child td { border-bottom: none; }
    th { background: var(--code-bg); font-weight: 600; }
    img { max-width: 100%; border-radius: 8px; }
    hr { border: none; height: 1px; background: var(--border); margin: 2.2em 0; }
    """
}
