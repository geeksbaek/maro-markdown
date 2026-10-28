import AppKit
import MaroRenderer
import SwiftUI
import WebKit

/// A read-only, live GitHub-style preview. Markdown is rendered before it reaches this view.
struct MarkdownPreview: NSViewRepresentable {
    let html: String
    let fileURL: URL?
    var fontSize: CGFloat = 16

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = view
        context.coordinator.baseURL = fileURL?.deletingLastPathComponent()
        context.coordinator.pendingHTML = html
        context.coordinator.pendingFontScale = min(max(Double(fontSize) / 16, 0.75), 2)
        context.coordinator.lastHTML = html
        context.coordinator.lastFontScale = context.coordinator.pendingFontScale
        view.loadHTMLString(PreviewPage.shell(content: html, scale: context.coordinator.pendingFontScale),
                            baseURL: context.coordinator.baseURL)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let nextBaseURL = fileURL?.deletingLastPathComponent()
        if nextBaseURL != coordinator.baseURL {
            coordinator.baseURL = nextBaseURL
            coordinator.ready = false
            coordinator.lastHTML = nil
            view.loadHTMLString(PreviewPage.shell(content: html, scale: min(max(Double(fontSize) / 16, 0.75), 2)),
                                baseURL: nextBaseURL)
        }

        coordinator.pendingHTML = html
        coordinator.pendingFontScale = min(max(Double(fontSize) / 16, 0.75), 2)
        coordinator.flushIfReady()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        var baseURL: URL?
        var ready = false
        var pendingHTML = ""
        var pendingFontScale = 1.0
        var lastHTML: String?
        var lastFontScale: Double?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            flushIfReady()
        }

        func flushIfReady() {
            guard ready, let webView,
                  pendingHTML != lastHTML || pendingFontScale != lastFontScale else { return }

            // JSON encoding keeps document text out of JavaScript syntax and the HTML shell.
            guard let encoded = try? JSONEncoder().encode(pendingHTML),
                  let literal = String(data: encoded, encoding: .utf8) else { return }
            let scale = pendingFontScale
            let script = """
            (() => {
              const root = document.getElementById('markdown');
              if (!root) return;
              const oldMax = Math.max(1, document.documentElement.scrollHeight - innerHeight);
              const progress = scrollY / oldMax;
              root.innerHTML = \(literal);
              document.documentElement.style.setProperty('--preview-scale', '\(scale)');
              requestAnimationFrame(() => {
                const newMax = Math.max(0, document.documentElement.scrollHeight - innerHeight);
                scrollTo(0, progress * newMax);
              });
            })();
            """
            webView.evaluateJavaScript(script) { [weak self, weak webView] _, error in
                guard error != nil, let self, let webView else { return }
                // Keep the preview usable on WebKit builds that disallow native script evaluation.
                self.ready = false
                webView.loadHTMLString(PreviewPage.shell(content: self.pendingHTML, scale: self.pendingFontScale),
                                       baseURL: self.baseURL)
            }
            lastHTML = pendingHTML
            lastFontScale = scale
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                return .allow
            }
            return routeLink(url, in: webView) ? .allow : .cancel
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                _ = routeLink(url, in: webView)
            }
            return nil
        }

        private func routeLink(_ url: URL, in webView: WKWebView) -> Bool {
            if let fragment = url.fragment,
               url.scheme == "about" || (url.isFileURL && url.path == baseURL?.path) {
                let identifier = fragment.removingPercentEncoding ?? fragment
                if let encoded = try? JSONEncoder().encode(identifier),
                   let literal = String(data: encoded, encoding: .utf8) {
                    webView.evaluateJavaScript("document.getElementById(\(literal))?.scrollIntoView({behavior:'smooth'});", completionHandler: nil)
                }
                return false
            }

            switch url.scheme?.lowercased() {
            case "http", "https", "mailto":
                NSWorkspace.shared.open(url)
            case "file":
                // File links are opened by Launch Services, never navigated inside the preview.
                NSWorkspace.shared.open(url)
            default:
                break
            }
            return false
        }
    }
}
