import Foundation

/// How a Markdown file's bytes map to text, so it can be written back the same way.
public enum SourceEncoding: Sendable {
    case utf8
    case utf8BOM
    case utf16LE
    case utf16BE

    public var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM: .utf8
        case .utf16LE: .utf16LittleEndian
        case .utf16BE: .utf16BigEndian
        }
    }

    public var byteOrderMark: Data {
        switch self {
        case .utf8: Data()
        case .utf8BOM: Data([0xEF, 0xBB, 0xBF])
        case .utf16LE: Data([0xFF, 0xFE])
        case .utf16BE: Data([0xFE, 0xFF])
        }
    }

    /// Detects the encoding from the byte order mark (UTF-8 without one).
    public static func detect(_ data: Data) -> SourceEncoding {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8BOM }
        if data.starts(with: [0xFF, 0xFE]) { return .utf16LE }
        if data.starts(with: [0xFE, 0xFF]) { return .utf16BE }
        return .utf8
    }

    /// Decodes strictly; returns nil for malformed input.
    public static func decode(_ data: Data) -> (text: String, encoding: SourceEncoding)? {
        let encoding = detect(data)
        let body = data.dropFirst(encoding.byteOrderMark.count)
        return String(data: body, encoding: encoding.stringEncoding).map { ($0, encoding) }
    }

    /// Decodes with replacement characters, which also tolerates a buffer cut mid-character.
    public static func decodeLossily(_ data: Data) -> String {
        let encoding = detect(data)
        let body = data.dropFirst(encoding.byteOrderMark.count)
        switch encoding {
        case .utf8, .utf8BOM:
            return String(decoding: body, as: UTF8.self)
        case .utf16LE, .utf16BE:
            let units = stride(from: body.startIndex, to: body.endIndex - 1, by: 2).map { index in
                let first = UInt16(body[index]), second = UInt16(body[index + 1])
                return encoding == .utf16LE ? first | second << 8 : first << 8 | second
            }
            return String(decoding: units, as: UTF16.self)
        }
    }
}
