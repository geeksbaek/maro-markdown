import XCTest
import MaroRenderer

final class SourceEncodingTests: XCTestCase {
    func testDetectsAndStripsByteOrderMarks() throws {
        let text = "# 제목 🧭\r\n本文"
        for encoding in [SourceEncoding.utf8, .utf8BOM, .utf16LE, .utf16BE] {
            let data = encoding.byteOrderMark + text.data(using: encoding.stringEncoding)!
            let decoded = try XCTUnwrap(SourceEncoding.decode(data))
            XCTAssertEqual(decoded.text, text)
            XCTAssertEqual(decoded.encoding, encoding)
            XCTAssertEqual(SourceEncoding.decodeLossily(data), text)
        }
    }

    func testStrictDecodeRejectsMalformedUTF8() {
        XCTAssertNil(SourceEncoding.decode(Data([0x23, 0x20, 0xFF])))
    }

    func testLossyDecodeToleratesTruncatedUTF16() {
        let data = SourceEncoding.utf16LE.byteOrderMark + "한글".data(using: .utf16LittleEndian)!
        // Cut in the middle of the last code unit, as a byte-limited prefix can.
        XCTAssertEqual(SourceEncoding.decodeLossily(data.dropLast()), "한")
    }
}
