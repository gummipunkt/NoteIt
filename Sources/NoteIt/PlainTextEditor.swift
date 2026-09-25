import AppKit
import SwiftUI

/// A plain text editor (NSTextView) with typographic "smart" substitutions turned off,
/// so Markdown stays exactly as typed.
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    /// Changes when another note is shown; resets undo history and scroll position.
    var noteID: String
    var fontSize: Double
    var monospaced: Bool
    var focusRequest: Int
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.string = text
        context.coordinator.noteID = noteID
        applyFont(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            if coordinator.noteID == noteID {
                // Same note changed from outside (e.g. Dropbox): keep the cursor where it was if possible.
                let length = (text as NSString).length
                textView.selectedRanges = selection.map { value in
                    let range = value.rangeValue
                    let location = min(range.location, length)
                    return NSValue(range: NSRange(location: location, length: min(range.length, length - location)))
                }
            }
        }
        if coordinator.noteID != noteID {
            coordinator.noteID = noteID
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
        applyFont(to: textView)

        if coordinator.lastFocusRequest != focusRequest {
            coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func applyFont(to textView: NSTextView) {
        let size = CGFloat(fontSize)
        let font: NSFont = monospaced
            ? .monospacedSystemFont(ofSize: size, weight: .regular)
            : .systemFont(ofSize: size)
        if textView.font != font {
            textView.font = font
            textView.typingAttributes[.font] = font
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        var noteID: String?
        var lastFocusRequest: Int

        init(parent: PlainTextEditor) {
            self.parent = parent
            self.lastFocusRequest = parent.focusRequest
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // Esc goes back to the search field (like nvALT) instead of triggering completion.
            if selector == #selector(NSResponder.cancelOperation(_:)) || selector == #selector(NSResponder.complete(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}
