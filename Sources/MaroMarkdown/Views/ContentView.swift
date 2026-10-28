import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @StateObject private var editor = EditorController()
    @SceneStorage("editorMode") private var editorMode = EditorMode.split.rawValue
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @State private var renderedHTML = ""
    @State private var renderError: String?

    private var mode: EditorMode {
        EditorMode(rawValue: editorMode) ?? .split
    }

    private var lineCount: Int {
        if document.text.isEmpty { return 1 }
        return document.text.reduce(into: 1) { count, character in
            if character == "\n" { count += 1 }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch mode {
                case .source:
                    editorPane
                case .split:
                    HSplitView {
                        editorPane.frame(minWidth: 300)
                        previewPane.frame(minWidth: 300)
                    }
                case .preview:
                    previewPane
                }
            }
            statusBar
        }
        .frame(minWidth: 650, minHeight: 440)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editor.showFind()
                } label: {
                    Label("찾기", systemImage: "magnifyingglass")
                }
                .disabled(mode == .preview)
                .help("문서에서 찾기 ⌘F")

                Menu {
                    Button("제목") { editor.insertLinePrefix("## ") }
                    Button("인용") { editor.insertLinePrefix("> ") }
                    Button("글머리 기호") { editor.insertLinePrefix("- ") }
                    Button("할 일") { editor.insertLinePrefix("- [ ] ") }
                    Divider()
                    Button("굵게") {
                        editor.insertSurrounding(prefix: "**", suffix: "**", placeholder: "굵은 텍스트")
                    }
                    Button("기울임") {
                        editor.insertSurrounding(prefix: "*", suffix: "*", placeholder: "기울인 텍스트")
                    }
                    Button("인라인 코드") {
                        editor.insertSurrounding(prefix: "`", suffix: "`", placeholder: "코드")
                    }
                    Button("링크") {
                        editor.insertSurrounding(prefix: "[", suffix: "](https://)", placeholder: "링크 텍스트")
                    }
                } label: {
                    Label("서식", systemImage: "textformat")
                }
                .disabled(mode == .preview)

                Picker("보기", selection: $editorMode) {
                    ForEach(EditorMode.allCases) { choice in
                        Label(choice.title, systemImage: choice.systemImage)
                            .tag(choice.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
        }
        .focusedValue(\.markdownEditor, editor)
        .task(id: document.text) {
            do {
                try await Task.sleep(for: .milliseconds(140))
                try Task.checkCancellation()
                renderedHTML = try MarkdownRenderer.renderHTML(document.text)
                renderError = nil
            } catch is CancellationError {
                return
            } catch {
                renderError = error.localizedDescription
            }
        }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            paneHeader("편집", detail: "MARKDOWN")
            MarkdownTextEditor(
                text: $document.text,
                controller: editor,
                fontSize: CGFloat(editorFontSize)
            )
        }
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            paneHeader("미리보기", detail: "GITHUB FLAVORED MARKDOWN")
            if let renderError {
                ContentUnavailableView(
                    "미리보기를 표시할 수 없습니다",
                    systemImage: "exclamationmark.triangle",
                    description: Text(renderError)
                )
            } else {
                MarkdownPreview(
                    html: renderedHTML,
                    fileURL: fileURL,
                    fontSize: CGFloat(previewFontSize)
                )
            }
        }
    }

    private func paneHeader(_ title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption.weight(.semibold))
            Text(detail).font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 33)
        .background(.bar)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Text(fileURL?.lastPathComponent ?? "새 문서")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("\(lineCount)줄")
            Text("\(document.text.count)자")
            Text("GFM \(MarkdownRenderer.engineVersion)")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(.bar)
    }
}
