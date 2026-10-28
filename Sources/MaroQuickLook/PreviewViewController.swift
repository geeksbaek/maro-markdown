import AppKit
import MaroRenderer
import QuickLookUI
import WebKit

/// Finder's Quick Look (space bar) preview. A view-based preview hosts the same WebKit
/// page as the app, so the bundled KaTeX and Mermaid scripts can render math and diagrams.
// Quick Look calls the controller on the main thread; @preconcurrency checks that at runtime.
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController, WKNavigationDelegate {
    // Quick Look only needs a readable preview, so very large files are cut off.
    private static let maximumBytes = 4 * 1024 * 1024
    /// Upper bound on waiting for the page, so a stuck load never leaves Quick Look spinning.
    private static let readyTimeout: TimeInterval = 3
    private static let size = NSSize(width: 900, height: 1100)

    private var webView: WKWebView?
    private var completion: ((Error?) -> Void)?
    private var committed = false

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.size))
        preferredContentSize = Self.size
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let text = SourceEncoding.decodeLossily(data.prefix(Self.maximumBytes))
            let body = try MarkdownRenderer.renderHTML(text)

            // Only the libraries this document uses, so plain documents skip Mermaid's 5 MB.
            let configuration = PreviewWebView.configuration(features: .init(html: body))
            let webView = WKWebView(frame: view.bounds, configuration: configuration)
            webView.autoresizingMask = [.width, .height]
            webView.navigationDelegate = self
            webView.setValue(false, forKey: "drawsBackground")
            view.addSubview(webView)
            self.webView = webView

            completion = handler
            // The sandbox grants only the previewed file; offline also drops remote images,
            // which otherwise keep the page from ever loading here.
            webView.loadHTMLString(PreviewPage.shell(content: body, offline: true),
                                   baseURL: url.deletingLastPathComponent())
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.readyTimeout) { [weak self] in
                self?.finishLoading()
            }
        } catch {
            handler(error)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        committed = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for math and diagrams so Quick Look shows the rendered page, not the source.
        webView.callAsyncJavaScript(PreviewScripts.awaitFirstRender, arguments: [:], in: nil, in: .page) { [weak self] _ in
            self?.finishLoading()
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        committed = false
        finishLoading()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard navigationAction.navigationType == .linkActivated else { return .allow }
        // In-page links scroll; every other link stays inert in the preview.
        if let url = navigationAction.request.url, let fragment = url.fragment,
           url.scheme == "about" || url.isFileURL {
            PreviewWebView.scroll(webView, toFragment: fragment)
        }
        return .cancel
    }

    /// Completes the preview. A page that never appeared reports an error, so Quick Look
    /// shows its own fallback instead of an empty panel.
    private func finishLoading() {
        guard let handler = completion else { return }
        completion = nil
        handler(committed ? nil : CocoaError(.fileReadUnknown))
    }
}
