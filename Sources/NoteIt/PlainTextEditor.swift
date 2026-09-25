import AppKit
import NoteItCore
import SwiftUI

enum EditorFontStyle: String, CaseIterable, Identifiable {
    case system
    case serif
    case mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System (SF Pro)"
        case .serif: return "Serif (New York)"
        case .mono: return "Festbreite (SF Mono)"
        }
    }

    func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .system:
            return .systemFont(ofSize: size, weight: weight)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withDesign(.serif), let font = NSFont(descriptor: descriptor, size: size) {
                return font
            }
            return base
        case .mono:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }
}

/// The note editor: a plain text NSTextView with live Markdown highlighting,
/// no "smart" substitutions, and an optional centered text column.
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    /// Changes when another note is shown; resets undo history and scroll position.
    var noteID: String
    var isMarkdown: Bool
    var fontStyle: EditorFontStyle
    var fontSize: Double
    /// Maximum width of the text column; `nil` uses the full width.
    var maxTextWidth: CGFloat?
    var focusRequest: Int
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
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
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.noteID = noteID
        coordinator.highlighter = highlighter
        textView.string = text
        coordinator.rehighlight()

        scrollView.contentView.postsFrameChangedNotifications = true
        coordinator.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coordinator] _ in
            MainActor.assumeIsolated { coordinator?.updateInsets() }
        }
        coordinator.updateInsets()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let newHighlighter = highlighter
        let styleChanged = coordinator.highlighter != newHighlighter
        coordinator.highlighter = newHighlighter

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
        } else if styleChanged {
            coordinator.rehighlight()
        }

        if coordinator.noteID != noteID {
            coordinator.noteID = noteID
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
        coordinator.updateInsets()

        if coordinator.lastFocusRequest != focusRequest {
            coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        if let observer = coordinator.frameObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private var highlighter: MarkdownHighlighter {
        MarkdownHighlighter(fontStyle: fontStyle, fontSize: CGFloat(fontSize), isMarkdown: isMarkdown)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: PlainTextEditor
        weak var textView: NSTextView?
        var noteID: String?
        var lastFocusRequest: Int
        var highlighter: MarkdownHighlighter?
        var frameObserver: NSObjectProtocol?

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

        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            highlighter?.apply(to: textStorage)
        }

        func rehighlight() {
            guard let textView, let storage = textView.textStorage, let highlighter else { return }
            storage.beginEditing()
            highlighter.apply(to: storage)
            storage.endEditing()
            textView.typingAttributes = highlighter.baseAttributes
        }

        /// Centers the text in a column of at most `maxTextWidth` points.
        func updateInsets() {
            guard let textView, let scrollView = textView.enclosingScrollView else { return }
            let width = scrollView.contentView.bounds.width
            let minimum: CGFloat = 28
            var horizontal = minimum
            if let maxWidth = parent.maxTextWidth {
                horizontal = max(minimum, (width - maxWidth) / 2)
            }
            let inset = NSSize(width: horizontal.rounded(), height: 6)
            if textView.textContainerInset != inset {
                textView.textContainerInset = inset
            }
        }
    }
}

/// Styles Markdown source in the editor (headings larger, emphasis, code, links …).
struct MarkdownHighlighter: Equatable {
    var fontStyle: EditorFontStyle
    var fontSize: CGFloat
    var isMarkdown: Bool

    var baseFont: NSFont { fontStyle.font(size: fontSize) }

    var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.3
        paragraph.paragraphSpacing = fontSize * 0.35
        return [
            .font: baseFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph,
        ]
    }

    func apply(to storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)
        storage.setAttributes(baseAttributes, range: full)
        // Very large files stay plain to keep typing fast.
        guard isMarkdown, storage.length < 300_000 else { return }

        let accent = NSColor.controlAccentColor
        let monoFont = NSFont.monospacedSystemFont(ofSize: fontSize * 0.92, weight: .regular)

        for token in MarkdownSyntax.tokens(in: storage.string) {
            let range = token.range
            switch token.kind {
            case .heading(let level):
                let scale: CGFloat = [1.55, 1.32, 1.16, 1.06, 1.0, 1.0][min(level, 6) - 1]
                storage.addAttribute(.font, value: fontStyle.font(size: fontSize * scale, weight: .bold), range: range)
            case .marker:
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
            case .bold:
                addTrait(.boldFontMask, in: range, of: storage)
            case .italic:
                addTrait(.italicFontMask, in: range, of: storage)
            case .strikethrough:
                storage.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ], range: range)
            case .inlineCode:
                storage.addAttributes([
                    .font: monoFont,
                    .foregroundColor: NSColor.systemPink,
                    .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                ], range: range)
            case .codeBlock:
                storage.addAttributes([
                    .font: monoFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ], range: range)
            case .blockquote:
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
                addTrait(.italicFontMask, in: range, of: storage)
            case .listMarker:
                storage.addAttribute(.foregroundColor, value: accent, range: range)
            case .taskBox(let checked):
                storage.addAttributes([
                    .foregroundColor: checked ? NSColor.systemGreen : accent,
                    .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
                ], range: range)
            case .link:
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            case .wikiLink:
                storage.addAttributes([
                    .foregroundColor: accent,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: accent.withAlphaComponent(0.4),
                ], range: range)
            case .horizontalRule:
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
            }
        }
    }

    private func addTrait(_ trait: NSFontTraitMask, in range: NSRange, of storage: NSTextStorage) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? NSFont) ?? baseFont
            let converted = NSFontManager.shared.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: converted, range: subrange)
        }
    }
}
