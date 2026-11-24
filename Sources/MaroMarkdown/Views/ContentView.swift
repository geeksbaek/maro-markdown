import AppKit
import MaroRenderer
import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @StateObject private var editor = EditorController()
    @SceneStorage("editorMode") private var editorMode = EditorMode.preview.rawValue
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @State private var renderedHTML = ""
    @State private var renderError: String?
    /// The file changed on disk while this window had unsaved edits.
    @State private var diskChangePending = false

    private var mode: EditorMode {
        EditorMode(rawValue: editorMode) ?? .preview
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
            if diskChangePending {
                diskChangeBar
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
        .task(id: fileURL) {
            diskChangePending = false
            guard let fileURL else { return }
            for await _ in FileWatcher.changes(at: fileURL) {
                // Let a write in progress finish before reading the file.
                try? await Task.sleep(for: .milliseconds(150))
                if Task.isCancelled { return }
                reloadFromDisk(fileURL)
            }
        }
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

    /// Reloads the file after another app changed it. Unsaved edits in this
    /// window are never replaced without asking.
    private func reloadFromDisk(_ url: URL, discardingEdits: Bool = false) {
        guard let data = try? Data(contentsOf: url),
              let decoded = SourceEncoding.decode(data) else { return }
        let fileDocument = NSDocumentController.shared.document(for: url)
        let diskDate = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        let change = DiskChange.decide(
            diskText: decoded.text,
            windowText: document.text,
            diskDate: diskDate,
            lastSaveDate: fileDocument?.fileModificationDate,
            hasUnsavedEdits: fileDocument?.isDocumentEdited ?? false,
            discardingEdits: discardingEdits
        )
        switch change {
        case .upToDate:
            diskChangePending = false
            return
        case .ownSave:
            return
        case .conflict:
            diskChangePending = true
            return
        case .reload:
            break
        }
        guard let fileDocument else {
            document.text = decoded.text
            diskChangePending = false
            return
        }

        do {
            // Reverting reads the file through MarkdownDocument, keeping its
            // encoding, and leaves the document without unsaved changes.
            try fileDocument.revert(toContentsOf: url, ofType: fileDocument.fileType ?? "net.daringfireball.markdown")
            diskChangePending = false
        } catch {
            fileDocument.presentError(error)
        }
    }

    private var diskChangeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
            Text("다른 앱에서 파일이 바뀌었습니다. 저장하지 않은 수정이 있어 다시 불러오지 않았습니다.")
                .lineLimit(2)
            Spacer()
            Button("수정 유지") { diskChangePending = false }
            Button("다시 불러오기") {
                if let fileURL { reloadFromDisk(fileURL, discardingEdits: true) }
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.18))
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
