import Foundation

/// The HTML page around rendered Markdown, shared by the app preview and Quick Look.
public enum PreviewPage {
    public static let css: String = Bundle.module.url(forResource: "github-markdown", withExtension: "css")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    public static func shell(content: String, scale: Double = 1) -> String {
        return """
        <!doctype html>
        <html lang="und"><head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' file: data: https: http:; style-src 'unsafe-inline'; script-src 'none'; object-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'">
          <style>\(css)</style>
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
            @media (max-width: 620px) { .markdown-body { padding: 24px 20px 72px; } }
            @media print { .markdown-body { max-width: none; padding: 0; } }
          </style>
        </head><body><article id="markdown" class="markdown-body">\(content)</article></body></html>
        """
    }
}
