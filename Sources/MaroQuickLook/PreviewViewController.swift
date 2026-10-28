import AppKit
import MaroRenderer
import QuickLookUI
import WebKit

/// Finder's Quick Look (space bar) preview. A view-based preview hosts the same WebKit
/// page as the app, so the bundled KaTeX and Mermaid scripts can render math and diagrams.
// Quick Look calls the controller on the main thread; @preconcurrency checks that at runtime.
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController, WKNavigationDelegate {
    // Quick Look only needs a readable preview, so very large files are cut off.
    private nonisolated static let maximumBytes = 4 * 1024 * 1024
    /// How long the page may take to appear; a cold WebKit start can take a few seconds.
    private static let loadTimeout: TimeInterval = 10
    /// How long to wait for math and diagrams once the page is up, before showing it anyway.
    private static let renderTimeout: TimeInterval = 3
    private static let size = NSSize(width: 900, height: 1100)

    private var webView: WKWebView?
    private var baseURL: URL?
    private var completion: ((Error?) -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.size))
        preferredContentSize = Self.size
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        completion = handler
        // Reading and rendering up to 4 MB stays off the main thread.
        Task.detached(priority: .userInitiated) {
            let result = Result { () throws -> String in
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                return try MarkdownRenderer.renderHTML(SourceEncoding.decodeLossily(data.prefix(Self.maximumBytes)))
            }
            await MainActor.run { self.show(result, for: url) }
        }
    }

    private func show(_ result: Result<String, Error>, for url: URL) {
        guard case .success(let body) = result else {
            if case .failure(let error) = result { finish(error) }
            return
        }
        let features = PreviewWebView.Features(html: body)
        // Only the libraries this document uses, so plain documents skip Mermaid's 5 MB.
        let webView = WKWebView(frame: view.bounds, configuration: PreviewWebView.configuration(features: features))
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        view.addSubview(webView)
        self.webView = webView

        baseURL = url.deletingLastPathComponent()
        // The sandbox grants only the previewed file; offline also drops remote images,
        // which otherwise keep the page from ever loading here.
        webView.loadHTMLString(PreviewPage.shell(content: body, offline: true, math: features.math), baseURL: baseURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadTimeout) { [weak self] in
            // The page never appeared: let Quick Look show its own fallback, not an empty panel.
            self?.finish(CocoaError(.fileReadUnknown))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for math and diagrams so Quick Look shows the rendered page, not the source.
        webView.callAsyncJavaScript(PreviewScripts.awaitFirstRender, arguments: [:], in: nil, in: .page) { [weak self] _ in
            self?.finish(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.renderTimeout) { [weak self] in
            self?.finish(nil)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(CocoaError(.fileReadUnknown))
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard navigationAction.navigationType == .linkActivated else { return .allow }
        // In-page links scroll; every other link stays inert in the preview.
        if let url = navigationAction.request.url,
           let fragment = PreviewWebView.inPageFragment(of: url, baseURL: baseURL) {
            PreviewWebView.scroll(webView, toFragment: fragment)
        }
        return .cancel
    }

    /// Completes the preview once; later calls (timeouts, late callbacks) do nothing.
    private func finish(_ error: Error?) {
        let handler = completion
        completion = nil
        handler?(error)
    }
}
