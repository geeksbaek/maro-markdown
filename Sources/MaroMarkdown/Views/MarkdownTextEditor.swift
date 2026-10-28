import AppKit
import SwiftUI

@MainActor
final class EditorController: ObservableObject {
    weak var textView: NSTextView?

    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    func showFind() {
        guard let textView else { return }
        focus()
        let item = NSMenuItem()
        item.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        textView.performFindPanelAction(item)
    }

    func insertSurrounding(prefix: String, suffix: String, placeholder: String) {
        guard let textView else { return }
        focus()

        let source = textView.string as NSString
        let selection = clamped(textView.selectedRange(), to: source.length)
        let selectedText = source.substring(with: selection)
        let content = selectedText.isEmpty ? placeholder : selectedText
        textView.insertText(prefix + content + suffix, replacementRange: selection)
        textView.setSelectedRange(
            NSRange(
                location: selection.location + (prefix as NSString).length,
                length: (content as NSString).length
            )
        )
    }

    func insertLinePrefix(_ prefix: String) {
        guard let textView, !prefix.isEmpty else { return }
        focus()

        let source = textView.string as NSString
        let selection = clamped(textView.selectedRange(), to: source.length)
        let firstLine = source.lineRange(for: NSRange(location: selection.location, length: 0))
        let lastPosition = selection.length == 0
            ? selection.location
            : selection.location + selection.length - 1
        let lastLine = source.lineRange(for: NSRange(location: lastPosition, length: 0))
        let lineRange = NSRange(
            location: firstLine.location,
            length: NSMaxRange(lastLine) - firstLine.location
        )

        let original = source.substring(with: lineRange) as NSString
        let replacement = NSMutableString(string: original as String)
        var lineStarts = [0]
        if original.length > 0 {
            for index in 0..<original.length {
                let scalar = original.character(at: index)
                let next = index + 1
                if scalar == 10 && next < original.length {
                    lineStarts.append(next)
                } else if scalar == 13 && next < original.length && original.character(at: next) != 10 {
                    lineStarts.append(next)
                }
            }
        }
        for offset in lineStarts.reversed() {
            replacement.insert(prefix, at: offset)
        }

        let replacementText = replacement as String
        textView.insertText(replacementText, replacementRange: lineRange)
        if selection.length == 0 {
            textView.setSelectedRange(
                NSRange(location: selection.location + (prefix as NSString).length, length: 0)
            )
        } else {
            textView.setSelectedRange(
                NSRange(location: lineRange.location, length: (replacementText as NSString).length)
            )
        }
    }

    private func clamped(_ range: NSRange, to length: Int) -> NSRange {
        let location = min(max(0, range.location), length)
        let available = length - location
        return NSRange(location: location, length: min(max(0, range.length), available))
    }
}

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    let controller: EditorController
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.font = .monospacedSystemFont(ofSize: max(11, fontSize), weight: .regular)
        textView.string = text
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel("Markdown source editor")

        scrollView.documentView = textView
        controller.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        controller.textView = textView

        let desiredFont = NSFont.monospacedSystemFont(ofSize: max(11, fontSize), weight: .regular)
        if textView.font != desiredFont {
            textView.font = desiredFont
        }

        guard textView.string != text, !textView.hasMarkedText() else { return }
        let previousSelection = textView.selectedRange()
        textView.string = text
        let length = (text as NSString).length
        let location = min(previousSelection.location, length)
        textView.setSelectedRange(
            NSRange(location: location, length: min(previousSelection.length, length - location))
        )
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // A mode switch or window close tears the editor down mid-composition;
        // commit the IME text so it reaches the document instead of vanishing.
        // SwiftUI calls this during a view update, so the binding write waits a turn.
        textView.delegate = nil
        let committed = coordinator.endComposition(in: textView)
        DispatchQueue.main.async {
            coordinator.push(committed)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !textView.hasMarkedText() else { return }
            push(textView.string)
        }

        /// Accepts the marked IME text as typed and returns the full editor text.
        func endComposition(in textView: NSTextView) -> String {
            if textView.hasMarkedText() {
                textView.unmarkText()
            }
            return textView.string
        }

        func push(_ updated: String) {
            if text.wrappedValue != updated {
                text.wrappedValue = updated
            }
        }
    }
}
