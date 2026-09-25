import AppKit
import NoteItCore
import SwiftUI
import WebKit

/// Live Markdown preview. `[[Wiki Links]]` open (or create) the linked note,
/// other links open in the default browser.
struct MarkdownPreview: NSViewRepresentable {
    var note: Note
    var baseURL: URL?
    var noteExists: (String) -> Bool
    var onWikiLink: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Notes may contain raw HTML; never run scripts from note content.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.render(note, in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownPreview
        private var loadedNoteID: String?
        private var lastBody: String?
        private var isLoaded = false

        init(parent: MarkdownPreview) {
            self.parent = parent
        }

        func render(_ note: Note, in webView: WKWebView) {
            let body = MarkdownRenderer.htmlBody(for: note, noteExists: parent.noteExists)
            if note.id == loadedNoteID, isLoaded {
                guard body != lastBody else { return }
                lastBody = body
                // Replace only the body so the scroll position is kept while typing.
                let encoded = (try? JSONEncoder().encode(body)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
                webView.evaluateJavaScript("document.body.innerHTML = \(encoded);", completionHandler: nil)
            } else {
                loadedNoteID = note.id
                lastBody = body
                isLoaded = false
                let html = MarkdownRenderer.htmlDocument(for: note, noteExists: parent.noteExists)
                webView.loadHTMLString(html, baseURL: parent.baseURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if let target = WikiLinks.target(from: url) {
                decisionHandler(.cancel)
                parent.onWikiLink(target)
            } else if url.fragment != nil, url.isFileURL || url.scheme == "about" {
                // Jump to an anchor within the preview.
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                NSWorkspace.shared.open(url)
            }
        }
    }
}
