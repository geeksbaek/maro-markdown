import Foundation

/// Removes image loads from rendered HTML for previews that must not touch the network
/// or the file system (Quick Look). Each `<img>` that is not a `data:` URL becomes a
/// placeholder showing its alt text.
///
/// In the Quick Look sandbox, any remote URL in the page keeps WebKit from ever committing
/// the load, so the page stays blank; a CSP refusal is not enough. Relative paths cannot be
/// read there either. Only cmark's `<img>` output references resources, because raw HTML
/// is omitted, so images are the only element that needs rewriting.
enum OfflineImages {
    private static let image = try! NSRegularExpression(pattern: "<img\\b[^>]*>", options: [.caseInsensitive])
    private static let source = try! NSRegularExpression(pattern: "\\bsrc=\"([^\"]*)\"", options: [.caseInsensitive])
    private static let alt = try! NSRegularExpression(pattern: "\\balt=\"([^\"]*)\"", options: [.caseInsensitive])

    static func strip(_ html: String) -> String {
        let text = html as NSString
        var result = ""
        var copied = 0
        for match in image.matches(in: html, range: NSRange(location: 0, length: text.length)) {
            let tag = text.substring(with: match.range)
            guard attribute(source, in: tag)?.hasPrefix("data:") != true else { continue }
            // The alt text is already HTML-escaped by cmark.
            let label = attribute(alt, in: tag).flatMap { $0.isEmpty ? nil : $0 } ?? "image"
            result += text.substring(with: NSRange(location: copied, length: match.range.location - copied))
            result += "<span class=\"maro-image-placeholder\">\(label)</span>"
            copied = NSMaxRange(match.range)
        }
        result += text.substring(from: copied)
        return result
    }

    private static func attribute(_ pattern: NSRegularExpression, in tag: String) -> String? {
        let text = tag as NSString
        guard let match = pattern.firstMatch(in: tag, range: NSRange(location: 0, length: text.length)) else {
            return nil
        }
        return text.substring(with: match.range(at: 1))
    }
}
