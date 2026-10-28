import AppKit
import MaroRenderer
import QuickLookUI
import WebKit

/// Finder's Quick Look (space bar) preview. A view-based preview hosts the same WebKit
/// page as the app, so the bundled KaTeX and Mermaid scripts can render math and diagrams.
// Quick Look calls the controller on the main thread; @preconcurrency checks that at runtime.
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController,
                                   WKNavigationDelegate, WKScriptMessageHandler {
    // Quick Look only needs a readable preview, so very large files are cut off.
    private static let maximumBytes = 4 * 1024 * 1024
    /// Upper bound on waiting for the page, so a stuck load never leaves Quick Look spinning.
    private static let readyTimeout: TimeInterval = 3

    private var webView: WKWebView!
    private var completion: ((Error?) -> Void)?

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        // The page CSP blocks every page script; only these bundled scripts run.
        for source in PreviewScripts.sources {
            configuration.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }
        // render.js posts here once math and diagrams are drawn.
        configuration.userContentController.add(WeakMessageHandler(self), name: PreviewScripts.renderedMessage)

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 1100), configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        view = webView
        preferredContentSize = NSSize(width: 900, height: 1100)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let text = SourceEncoding.decodeLossily(data.prefix(Self.maximumBytes))
            let body = OfflineImages.strip(try MarkdownRenderer.renderHTML(text))
            completion = handler
            webView.loadHTMLString(PreviewPage.shell(content: body, offline: true),
                                   baseURL: url.deletingLastPathComponent())
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.readyTimeout) { [weak self] in
                self?.finish()
            }
        } catch {
            handler(error)
        }
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        finish()
    }

    // A failed or crashed load still shows whatever the page has, rather than nothing.
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // Links stay inert in the preview; in-page anchors are handled by the page itself.
        navigationAction.navigationType == .linkActivated ? .cancel : .allow
    }

    private func finish() {
        let handler = completion
        completion = nil
        handler?(nil)
    }
}

/// WKUserContentController retains its handlers, and the controller owns the web view,
/// so the handler forwards through a weak reference to avoid a retain cycle.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
