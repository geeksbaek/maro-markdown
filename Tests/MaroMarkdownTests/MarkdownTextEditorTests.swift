import AppKit
import SwiftUI
import XCTest
@testable import MaroMarkdown

@MainActor
final class MarkdownTextEditorTests: XCTestCase {
    private final class Box {
        var text = ""
    }

    private func makeEditor() -> (NSTextView, MarkdownTextEditor.Coordinator, Box) {
        let box = Box()
        let binding = Binding(get: { box.text }, set: { box.text = $0 })
        let coordinator = MarkdownTextEditor.Coordinator(text: binding)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.delegate = coordinator
        return (textView, coordinator, box)
    }

    func testKoreanCompositionUpdatesBindingOnlyAfterCommit() {
        let (textView, _, box) = makeEditor()
        textView.insertText("안녕 ", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(box.text, "안녕 ")

        textView.setMarkedText("ㅎ", selectedRange: NSRange(location: 1, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        textView.setMarkedText("하", selectedRange: NSRange(location: 1, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(textView.hasMarkedText())
        XCTAssertEqual(box.text, "안녕 ")

        textView.insertText("한", replacementRange: textView.markedRange())
        XCTAssertFalse(textView.hasMarkedText())
        XCTAssertEqual(box.text, "안녕 한")
    }

    func testJapaneseConversionReplacesMarkedRange() {
        let (textView, _, box) = makeEditor()
        textView.setMarkedText("にほんご", selectedRange: NSRange(location: 4, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        textView.setMarkedText("日本語", selectedRange: NSRange(location: 3, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        textView.insertText("日本語", replacementRange: textView.markedRange())
        XCTAssertEqual(box.text, "日本語")
    }

    func testCommittingCompositionFlushesPendingText() {
        let (textView, coordinator, box) = makeEditor()
        textView.insertText("저장 ", replacementRange: NSRange(location: NSNotFound, length: 0))
        textView.setMarkedText("직", selectedRange: NSRange(location: 1, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(box.text, "저장 ")

        coordinator.commitComposition(in: textView)
        XCTAssertFalse(textView.hasMarkedText())
        XCTAssertEqual(box.text, "저장 직")
    }

    private final class Model: ObservableObject {
        @Published var text = "본문 "
        @Published var showEditor = true
    }

    private struct Host: View {
        @ObservedObject var model: Model
        let controller: EditorController

        var body: some View {
            if model.showEditor {
                MarkdownTextEditor(text: $model.text, controller: controller, fontSize: 14)
            } else {
                Text("preview")
            }
        }
    }

    /// Drives the real SwiftUI teardown path (mode switch) while IME text is marked.
    func testRemovingEditorMidCompositionKeepsText() throws {
        let model = Model()
        let controller = EditorController()
        // Never ordered front, so nothing appears on screen.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: Host(model: model, controller: controller))
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        let textView = try XCTUnwrap(controller.textView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.setMarkedText("한", selectedRange: NSRange(location: 1, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(model.text, "본문 ")

        model.showEditor = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        XCTAssertEqual(model.text, "본문 한")
        window.contentView = nil
    }
}
