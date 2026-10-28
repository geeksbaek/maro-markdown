import XCTest
@testable import MaroRenderer

final class OfflineImagesTests: XCTestCase {
    func testReplacesEveryNonDataImageWithItsAltText() throws {
        let html = try MarkdownRenderer.renderHTML("""
        ![원격](https://example.com/a.png) ![](rel.png "title") ![q&b](x?a=1&b=2)

        ![inline](data:image/png;base64,AA)
        """)
        let offline = OfflineImages.strip(html)

        XCTAssertFalse(offline.contains("https://example.com"))
        XCTAssertFalse(offline.contains("rel.png"))
        XCTAssertTrue(offline.contains("<span class=\"maro-image-placeholder\">원격</span>"))
        XCTAssertTrue(offline.contains("<span class=\"maro-image-placeholder\">image</span>"))
        XCTAssertTrue(offline.contains("<span class=\"maro-image-placeholder\">q&amp;b</span>"))
        // Inline data: images need no load and are kept.
        XCTAssertTrue(offline.contains("<img src=\"data:image/png;base64,AA\""))
    }

    func testLeavesHTMLWithoutImagesUnchanged() throws {
        let html = try MarkdownRenderer.renderHTML("# 제목\n\n[링크](https://example.com)")
        XCTAssertEqual(OfflineImages.strip(html), html)
    }

    func testOfflineShellStripsImagesAndAllowsOnlyDataImages() throws {
        let html = try MarkdownRenderer.renderHTML("![원격](https://example.com/a.png)")
        let page = PreviewPage.shell(content: html, offline: true)
        XCTAssertFalse(page.contains("https://example.com"))
        XCTAssertTrue(page.contains("img-src data:;"))
        XCTAssertTrue(PreviewPage.shell(content: html).contains("https://example.com/a.png"))
    }

    func testScriptsFollowTheFeaturesAPageUses() {
        let plain = PreviewWebView.Features(html: "<p>text</p>")
        XCTAssertEqual(PreviewScripts.sources(for: plain).count, 1, "only render.js")
        let math = PreviewWebView.Features(html: "<span class=\"maro-math\">x</span>")
        XCTAssertEqual(PreviewScripts.sources(for: math).count, 2)
        XCTAssertEqual(PreviewScripts.sources(for: .all).count, 3)
    }
}
