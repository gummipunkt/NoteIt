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
    public static func htmlDocument(for note: Note, noteExists: (String) -> Bool) -> String {
        let content = htmlBody(for: note, noteExists: noteExists)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapeHTML(note.title))</title>
        <style>\(stylesheet)</style>
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
      --text: #1d1d1f; --muted: #6e6e73; --bg: #ffffff; --code-bg: #f3f3f5;
      --border: #d9d9de; --link: #0a66d8; --missing: #c4331c;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --text: #e8e8ed; --muted: #a1a1a6; --bg: #1e1e1e; --code-bg: #2b2b2e;
        --border: #3a3a3d; --link: #5aa2ff; --missing: #ff7a66;
      }
    }
    html { background: var(--bg); }
    body {
      font: 15px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
      color: var(--text); background: var(--bg);
      max-width: 46em; margin: 0 auto; padding: 1.2em 1.6em 3em;
      word-wrap: break-word;
    }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.4em 0 0.5em; }
    h1 { font-size: 1.8em; } h2 { font-size: 1.45em; } h3 { font-size: 1.2em; }
    body > :first-child { margin-top: 0; }
    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    a[href^="noteit://note/"] { border-bottom: 1px solid currentColor; }
    a[href^="noteit://new/"] { color: var(--missing); border-bottom: 1px dashed currentColor; }
    code, pre { font: 0.9em/1.5 ui-monospace, "SF Mono", Menlo, monospace; }
    code { background: var(--code-bg); padding: 0.1em 0.35em; border-radius: 4px; }
    pre { background: var(--code-bg); padding: 0.8em 1em; border-radius: 6px; overflow-x: auto; }
    pre code { background: none; padding: 0; }
    pre.plain { background: none; padding: 0; white-space: pre-wrap; font-size: 0.95em; }
    blockquote { margin: 1em 0; padding: 0 1em; color: var(--muted); border-left: 3px solid var(--border); }
    table { border-collapse: collapse; margin: 1em 0; }
    th, td { border: 1px solid var(--border); padding: 0.35em 0.7em; }
    th { background: var(--code-bg); }
    img { max-width: 100%; }
    hr { border: none; border-top: 1px solid var(--border); margin: 2em 0; }
    li > p { margin: 0.2em 0; }
    input[type=checkbox] { margin-right: 0.4em; }
    """
}
