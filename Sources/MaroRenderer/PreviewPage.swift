import Foundation

/// The HTML page around rendered Markdown, shared by the app preview and Quick Look.
public enum PreviewPage {
    static let css: String = Bundle.module.url(forResource: "github-markdown", withExtension: "css")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    /// KaTeX's stylesheet with its woff2 fonts inlined as data: URLs. WebKit does not let a
    /// page loaded with a document's folder as its base read font files from the app bundle.
    static let katexCSS: String = {
        guard let vendor = PreviewScripts.vendorURL,
              let css = try? String(contentsOf: vendor.appendingPathComponent("katex/katex.min.css"), encoding: .utf8)
        else { return "" }
        let fonts = vendor.appendingPathComponent("katex/fonts")
        let fontFace = try! NSRegularExpression(pattern: "url\\(fonts/([A-Za-z0-9_-]+)\\.woff2\\) format\\(\"woff2\"\\)[^;}]*")
        let source = css as NSString
        var result = ""
        var copied = 0
        for match in fontFace.matches(in: css, range: NSRange(location: 0, length: source.length)) {
            let name = source.substring(with: match.range(at: 1))
            guard let data = try? Data(contentsOf: fonts.appendingPathComponent("\(name).woff2")) else { continue }
            result += source.substring(with: NSRange(location: copied, length: match.range.location - copied))
            // Only woff2 ships; the woff/ttf fallbacks after it are dropped.
            result += "url(data:font/woff2;base64,\(data.base64EncodedString())) format(\"woff2\")"
            copied = NSMaxRange(match.range)
        }
        result += source.substring(from: copied)
        return result
    }()

    public static func shell(content: String, scale: Double = 1) -> String {
        return """
        <!doctype html>
        <html lang="und"><head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' file: data: https: http:; style-src 'unsafe-inline'; font-src data:; script-src 'none'; object-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'">
          <style>\(css)</style>
          <style>\(katexCSS)</style>
          <style>
            :root { color-scheme: light dark; --preview-scale: \(scale); }
            html { scroll-behavior: auto; }
            body { margin: 0; background: #fff; }
            @media (prefers-color-scheme: dark) { body { background: #0d1117; } }
            .markdown-body {
              box-sizing: border-box;
              max-width: 1040px;
              min-height: 100vh;
              margin: 0 auto;
              padding: 32px clamp(24px, 5vw, 64px) 96px;
              font-size: calc(16px * var(--preview-scale));
              font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "PingFang TC", "Noto Sans CJK KR", "Noto Sans", sans-serif;
              word-break: normal;
              overflow-wrap: break-word;
              line-break: auto;
              -webkit-font-smoothing: antialiased;
            }
            .markdown-body pre, .markdown-body code { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace; }
            .markdown-body pre { overflow-x: auto; white-space: pre; }
            .markdown-body table { display: block; max-width: 100%; overflow-x: auto; }
            .markdown-body img { max-width: 100%; height: auto; }
            .markdown-body .task-list-item { list-style-type: none; }
            .markdown-body .task-list-item input[type=checkbox] { margin: 0 .5em .2em -1.5em; vertical-align: middle; }
            .markdown-body div.maro-math { margin: 0 0 16px; overflow-x: auto; overflow-y: hidden; }
            .markdown-body .maro-mermaid { margin: 0 0 16px; overflow-x: auto; }
            .markdown-body .maro-mermaid[data-rendered] { text-align: center; }
            /* Before the scripts run (and always in Quick Look, which cannot run them),
               math and diagrams show their source: inline as code, blocks as code blocks. */
            .markdown-body .maro-math:not([data-rendered]),
            .markdown-body .maro-mermaid:not([data-rendered]) { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace; font-size: 85%; }
            .markdown-body span.maro-math:not([data-rendered]) { padding: .2em .4em; border-radius: 6px; background-color: var(--bgColor-neutral-muted, rgba(129,139,152,.12)); }
            .markdown-body div.maro-math:not([data-rendered]),
            .markdown-body .maro-mermaid:not([data-rendered]) { padding: 16px; border-radius: 6px; line-height: 1.45; white-space: pre; text-align: left; background-color: var(--bgColor-muted, #f6f8fa); }
            .markdown-body .maro-mermaid svg { max-width: 100%; height: auto; }
            .markdown-body .maro-error { color: var(--fgColor-danger, #d1242f); text-align: left; }
            @media (max-width: 620px) { .markdown-body { padding: 24px 20px 72px; } }
            @media print { .markdown-body { max-width: none; padding: 0; } }
          </style>
        </head><body><article id="markdown" class="markdown-body">\(content)</article></body></html>
        """
    }
}

/// Scripts the app injects natively for math and Mermaid. The page CSP keeps
/// `script-src 'none'`, so only these scripts run, never anything from a document.
public enum PreviewScripts {
    static let vendorURL: URL? = Bundle.module.url(forResource: "vendor", withExtension: nil)

    /// Library sources in load order: KaTeX, Mermaid, then the renderer that uses them.
    public static let sources: [String] = {
        guard let vendor = vendorURL else { return [] }
        return ["katex/katex.min.js", "mermaid/mermaid.min.js", "render.js"].compactMap {
            try? String(contentsOf: vendor.appendingPathComponent($0), encoding: .utf8)
        }
    }()

    /// Re-renders math and diagrams after the preview content changes.
    public static let refresh = "window.maroRender && window.maroRender();"
}
