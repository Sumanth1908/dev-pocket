import AppKit
import SwiftUI

/// Colors ranges of the editor's text. Re-run on every change.
typealias Highlighter = (String) -> [(range: NSRange, color: NSColor)]

/// Monospaced plain-text editor with smart quotes, dashes and spell check
/// turned off — SwiftUI's `TextEditor` would happily corrupt JSON.
struct CodeEditor: View {
    @Binding var text: String
    var placeholder: String = ""
    var isEditable: Bool = true
    var highlighter: Highlighter?

    var body: some View {
        CodeTextView(text: $text, isEditable: isEditable, highlighter: highlighter)
            .overlay(alignment: .topLeading) {
                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
    }
}

private struct CodeTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var highlighter: Highlighter?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = EscapePassingTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.string = text
        textView.isEditable = isEditable
        applyHighlighting(to: textView)
        textView.textStorage?.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            applyHighlighting(to: textView)
        }
        textView.isEditable = isEditable
    }

    /// Recolors the whole text. Attribute changes don't touch undo.
    func applyHighlighting(to textView: NSTextView) {
        guard let highlighter, let storage = textView.textStorage else { return }
        let length = storage.length
        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: NSRange(location: 0, length: length))
        for (range, color) in highlighter(textView.string) where NSMaxRange(range) <= length {
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
        storage.endEditing()
        // Don't let new typing inherit the color of the character before it.
        textView.typingAttributes[.foregroundColor] = NSColor.textColor
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: CodeTextView
        weak var textView: NSTextView?

        init(_ parent: CodeTextView) { self.parent = parent }

        /// Typing: sync right away.
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.applyHighlighting(to: textView)
        }

        /// Undo/redo change the text without `textDidChange`, which left the
        /// binding stale. The storage sees every edit; sync after it settles.
        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                         range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let textView = self.textView, self.parent.text != textView.string else { return }
                self.parent.text = textView.string
                self.parent.applyHighlighting(to: textView)
            }
        }
    }
}

/// Esc in an `NSTextView` opens the completion popup; hand it to the
/// window instead so it closes the palette / hides the panel.
private final class EscapePassingTextView: NSTextView {
    override func cancelOperation(_ sender: Any?) {
        window?.cancelOperation(sender)
    }
}
