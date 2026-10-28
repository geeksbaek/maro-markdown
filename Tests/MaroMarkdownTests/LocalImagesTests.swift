import XCTest
import MaroRenderer

final class LocalImagesTests: XCTestCase {
    func testRewritesOnlyImagesInsideTheDocumentFolder() throws {
        let html = try MarkdownRenderer.renderHTML("""
        ![a](images/a.png) ![again](./images/a.png) ![space](images/my%20pic.png)
        ![up](../secret.png) ![abs](/etc/b.png) ![web](https://example.com/c.png)
        ![data](data:image/png;base64,AAAA) ![q](images/d.png?x=1&y=2)
        """)
        let folder = URL(fileURLWithPath: "/tmp/docs")
        let result = LocalImages.rewrite(html, relativeTo: folder)

        XCTAssertEqual(result.files.map(\.identifier), ["img0", "img1", "img2"])
        XCTAssertEqual(result.files.map(\.url.path), [
            "/tmp/docs/images/a.png", "/tmp/docs/images/my pic.png", "/tmp/docs/images/d.png"
        ])
        // The same file is attached once and referenced twice.
        XCTAssertEqual(result.html.components(separatedBy: "src=\"cid:img0\"").count - 1, 2)
        XCTAssertTrue(result.html.contains("src=\"../secret.png\""))
        XCTAssertTrue(result.html.contains("src=\"/etc/b.png\""))
        XCTAssertTrue(result.html.contains("src=\"https://example.com/c.png\""))
    }
}
