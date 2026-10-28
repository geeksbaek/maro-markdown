import SwiftUI

private struct MarkdownEditorKey: FocusedValueKey {
    typealias Value = EditorController
}

extension FocusedValues {
    var markdownEditor: EditorController? {
        get { self[MarkdownEditorKey.self] }
        set { self[MarkdownEditorKey.self] = newValue }
    }
}

struct MarkdownCommands: Commands {
    @FocusedValue(\.markdownEditor) private var editor

    var body: some Commands {
        CommandMenu("마크다운") {
            Button("굵게") {
                editor?.insertSurrounding(prefix: "**", suffix: "**", placeholder: "굵은 텍스트")
            }
            .keyboardShortcut("b")

            Button("기울임") {
                editor?.insertSurrounding(prefix: "*", suffix: "*", placeholder: "기울인 텍스트")
            }
            .keyboardShortcut("i")

            Button("인라인 코드") {
                editor?.insertSurrounding(prefix: "`", suffix: "`", placeholder: "코드")
            }
            .keyboardShortcut("e")

            Button("링크") {
                editor?.insertSurrounding(prefix: "[", suffix: "](https://)", placeholder: "링크 텍스트")
            }
            .keyboardShortcut("k")

            Divider()

            Button("제목") { editor?.insertLinePrefix("## ") }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("인용") { editor?.insertLinePrefix("> ") }
            Button("글머리 기호") { editor?.insertLinePrefix("- ") }
            Button("할 일") { editor?.insertLinePrefix("- [ ] ") }

            Divider()

            Button("찾기") { editor?.showFind() }
                .keyboardShortcut("f")
        }
    }
}
