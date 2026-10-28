import XCTest
@testable import MaroRenderer

final class QuickLookPageTests: XCTestCase {
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

    func testStripDoesNotDependOnAttributeOrder() {
        let html = "<p><img alt=\"뒤집힘\" src=\"https://example.com/a.png\" /><img src=\"https://example.com/b.png\"></p>"
        let offline = OfflineImages.strip(html)
        XCTAssertFalse(offline.contains("example.com"))
        XCTAssertTrue(offline.contains("<span class=\"maro-image-placeholder\">뒤집힘</span>"))
        XCTAssertTrue(offline.contains("<span class=\"maro-image-placeholder\">image</span>"))
    }

    func testMathStylesAreLeftOutWhenNotNeeded() {
        let withMath = PreviewPage.shell(content: "x", offline: true, math: true)
        let without = PreviewPage.shell(content: "x", offline: true, math: false)
        XCTAssertTrue(withMath.contains("KaTeX_Main"))
        XCTAssertFalse(without.contains("KaTeX_Main"))
    }

    func testInPageFragmentOnlyForLinksIntoThisDocument() {
        let base = URL(fileURLWithPath: "/tmp/docs/", isDirectory: true)
        XCTAssertEqual(PreviewWebView.inPageFragment(of: URL(string: "file:///tmp/docs/#%EC%84%A4%EC%B9%98")!, baseURL: base), "%EC%84%A4%EC%B9%98")
        XCTAssertEqual(PreviewWebView.inPageFragment(of: URL(string: "about:blank#x")!, baseURL: base), "x")
        XCTAssertNil(PreviewWebView.inPageFragment(of: URL(string: "file:///tmp/docs/other.md#x")!, baseURL: base))
        XCTAssertNil(PreviewWebView.inPageFragment(of: URL(string: "https://example.com/#x")!, baseURL: base))
        XCTAssertNil(PreviewWebView.inPageFragment(of: URL(string: "file:///tmp/docs/")!, baseURL: base))
    }

    func testFeatureDetectionIgnoresDocumentText() throws {
        let html = try MarkdownRenderer.renderHTML("이 글은 maro-mermaid 와 maro-math 라는 단어를 언급합니다.")
        let features = PreviewWebView.Features(html: html)
        XCTAssertFalse(features.math)
        XCTAssertFalse(features.diagrams)
        let both = PreviewWebView.Features(html: try MarkdownRenderer.renderHTML("$x$\n\n```mermaid\ngraph TD; A-->B\n```"))
        XCTAssertTrue(both.math)
        XCTAssertTrue(both.diagrams)
    }

    func testScriptsFollowTheFeaturesAPageUses() {
        let plain = PreviewWebView.Features(html: "<p>text</p>")
        XCTAssertEqual(PreviewScripts.sources(for: plain).count, 1, "only render.js")
        let math = PreviewWebView.Features(html: "<span class=\"maro-math\">x</span>")
        XCTAssertEqual(PreviewScripts.sources(for: math).count, 2)
        XCTAssertEqual(PreviewScripts.sources(for: .all).count, 3)
    }
}
