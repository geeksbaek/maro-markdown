import AppKit
import WebKit
import XCTest
@testable import MaroRenderer

/// Loads the real preview page offscreen, with scripts injected the way the app does,
/// and checks that math and diagrams render while document scripts stay blocked.
@MainActor
final class PreviewRenderingTests: XCTestCase {
    private final class Loader: NSObject, WKNavigationDelegate {
        var finished = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished = true }
    }

    private func evaluate(_ webView: WKWebView, _ script: String) async throws -> Any? {
        try await webView.evaluateJavaScript(script)
    }

    func testMathAndMermaidRenderAndPageScriptsStayBlocked() async throws {
        XCTAssertEqual(PreviewScripts.sources.count, 3, "KaTeX, Mermaid and render.js must be bundled")

        let markdown = """
        # 수식 $x^2$

        인라인 $\\alpha + \\beta$ 수식

        $$
        \\int_0^1 x\\,dx
        $$

        ```mermaid
        graph TD; A[한글]-->B
        ```

        <script>window.inlineRan = true</script>
        """
        let html = try MarkdownRenderer.renderHTML(markdown)
        let page = PreviewPage.shell(content: html + "<img src=x onerror=\"window.handlerRan=true\">")

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        for source in PreviewScripts.sources {
            configuration.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        let loader = Loader()
        webView.navigationDelegate = loader
        webView.loadHTMLString(page, baseURL: FileManager.default.temporaryDirectory)

        let deadline = Date().addingTimeInterval(15)
        while !loader.finished, Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(loader.finished)

        var state: [String: Any] = [:]
        while Date() < deadline {
            let json = try await evaluate(webView, """
            JSON.stringify({
              math: document.querySelectorAll('.maro-math .katex').length,
              display: document.querySelectorAll('.maro-math .katex-display').length,
              svg: document.querySelectorAll('.maro-mermaid svg').length,
              label: (document.querySelector('.maro-mermaid svg') || {}).textContent || '',
              inline: !!window.inlineRan,
              handler: !!window.handlerRan,
              font: [...document.fonts].some(f => f.family === 'KaTeX_Main' && f.status === 'loaded')
            })
            """) as? String ?? "{}"
            state = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] ?? [:]
            if state["svg"] as? Int == 1, state["font"] as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(100))
        }

        XCTAssertEqual(state["math"] as? Int, 3, "heading, inline and display formulas")
        XCTAssertEqual(state["display"] as? Int, 1)
        XCTAssertEqual(state["svg"] as? Int, 1)
        XCTAssertTrue((state["label"] as? String)?.contains("한글") == true)
        XCTAssertEqual(state["font"] as? Bool, true, "KaTeX fonts load from the bundle")
        XCTAssertEqual(state["inline"] as? Bool, false, "raw HTML scripts are omitted")
        XCTAssertEqual(state["handler"] as? Bool, false, "event handler attributes never run")
    }
}
