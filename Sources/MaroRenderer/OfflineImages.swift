import Foundation

/// Removes image loads from rendered HTML for previews that must not touch the network
/// or the file system (Quick Look). Each `<img>` that is not a `data:` URL becomes a
/// placeholder showing its alt text.
///
/// In the Quick Look sandbox, any remote URL in the page keeps WebKit from ever committing
/// the load, so the page stays blank; a CSP refusal is not enough. Relative paths cannot be
/// read there either. Only cmark's `<img>` output references resources, because raw HTML
/// is omitted, so images are the only element that needs rewriting.
public enum OfflineImages {
    private static let image = try! NSRegularExpression(pattern: "<img src=\"([^\"]*)\" alt=\"([^\"]*)\"[^>]*>")

    public static func strip(_ html: String) -> String {
        guard html.contains("<img") else { return html }
        let source = html as NSString
        var result = ""
        var copied = 0
        for match in image.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let src = source.substring(with: match.range(at: 1))
            guard !src.hasPrefix("data:") else { continue }
            // The alt text is already HTML-escaped by cmark.
            let alt = source.substring(with: match.range(at: 2))
            result += source.substring(with: NSRange(location: copied, length: match.range.location - copied))
            result += "<span class=\"maro-image-placeholder\">\(alt.isEmpty ? "image" : alt)</span>"
            copied = NSMaxRange(match.range)
        }
        result += source.substring(from: copied)
        return result
    }
}
