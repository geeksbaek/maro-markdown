import Foundation
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
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            guard let value = String(data: data.dropFirst(3), encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            text = value
            encoding = .utf8BOM
        } else if data.starts(with: [0xFF, 0xFE]) {
            guard let value = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            text = value
            encoding = .utf16LE
        } else if data.starts(with: [0xFE, 0xFF]) {
            guard let value = String(data: data.dropFirst(2), encoding: .utf16BigEndian) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            text = value
            encoding = .utf16BE
        } else if let value = String(data: data, encoding: .utf8) {
            text = value
            encoding = .utf8
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let body = text.data(using: encoding.stringEncoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: encoding.byteOrderMark + body)
    }
}

private enum SourceEncoding {
    case utf8
    case utf8BOM
    case utf16LE
    case utf16BE

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM: .utf8
        case .utf16LE: .utf16LittleEndian
        case .utf16BE: .utf16BigEndian
        }
    }

    var byteOrderMark: Data {
        switch self {
        case .utf8: Data()
        case .utf8BOM: Data([0xEF, 0xBB, 0xBF])
        case .utf16LE: Data([0xFF, 0xFE])
        case .utf16BE: Data([0xFE, 0xFF])
        }
    }
}
