import Foundation
import WebKit

/// WebKit setup shared by the app preview and the Quick Look preview, so both hosts
/// inject the same scripts under the same settings.
public enum PreviewWebView {
    /// What a page needs from the bundled libraries.
    public struct Features: Sendable {
        public var math: Bool
        public var diagrams: Bool

        public static let all = Features(math: true, diagrams: true)

        /// Only the libraries a rendered page actually uses. Matching the class attribute,
        /// not the bare name, keeps document text that mentions it from counting.
        public init(html: String) {
            self.init(math: html.contains("class=\"maro-math\""), diagrams: html.contains("class=\"maro-mermaid\""))
        }

        public init(math: Bool, diagrams: Bool) {
            self.math = math
            self.diagrams = diagrams
        }
    }

    /// A configuration whose only scripts are the bundled ones. The page CSP keeps
    /// `script-src 'none'`, so nothing a document references can run.
    @MainActor
    public static func configuration(features: Features = .all) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        for source in PreviewScripts.sources(for: features) {
            configuration.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }
        return configuration
    }

    /// The `#fragment` of a link that points into the page itself, or nil for links to other
    /// documents. A page loaded with `baseURL` resolves `#x` to the base folder's URL, so a
    /// link to `other.md#x` has a different path and is not in-page.
    public static func inPageFragment(of url: URL, baseURL: URL?) -> String? {
        guard let fragment = url.fragment else { return nil }
        if url.scheme == "about" { return fragment }
        guard url.isFileURL, let baseURL else { return nil }
        return url.standardizedFileURL.path == baseURL.standardizedFileURL.path ? fragment : nil
    }

    /// Scrolls to an in-page `#fragment`. Headings use GitHub's prefixed ids
    /// (`user-content-…`); footnotes keep cmark's bare ids.
    @MainActor
    public static func scroll(_ webView: WKWebView, toFragment fragment: String) {
        let identifier = fragment.removingPercentEncoding ?? fragment
        guard let encoded = try? JSONEncoder().encode([HeadingAnchors.idPrefix + identifier, identifier]),
              let literal = String(data: encoded, encoding: .utf8) else { return }
        webView.evaluateJavaScript("""
        (() => {
          const root = document.getElementById('markdown');
          const target = \(literal).map(id => document.getElementById(id))
            .find(node => node && node !== root);
          target?.scrollIntoView({behavior: 'smooth'});
        })();
        """, completionHandler: nil)
    }
}
