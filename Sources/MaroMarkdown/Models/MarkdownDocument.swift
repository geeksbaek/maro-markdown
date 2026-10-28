import Foundation
import MaroRenderer
import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.markdown, .plainText]
    static let writableContentTypes: [UTType] = [.markdown, .plainText]

    var text: String
    private var encoding: SourceEncoding

    init(text: String = "") {
        self.text = text
        self.encoding = .utf8
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let decoded = SourceEncoding.decode(data) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        text = decoded.text
        encoding = decoded.encoding
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let body = text.data(using: encoding.stringEncoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: encoding.byteOrderMark + body)
    }
}
