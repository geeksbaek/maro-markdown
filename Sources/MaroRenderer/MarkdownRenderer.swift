import CGFM
import Foundation

public enum MarkdownRenderError: LocalizedError {
    case renderingFailed
    case invalidOutput

    public var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return "마크다운을 렌더링하지 못했습니다."
        case .invalidOutput:
            return "렌더러가 올바르지 않은 UTF-8을 반환했습니다."
        }
    }
}

public struct MarkdownRenderer {
    public static var engineVersion: String {
        String(cString: cgfm_version_string())
    }

    public static func renderHTML(
        _ markdown: String,
        includeSourcePositions: Bool = false
    ) throws -> String {
        var math = MathExtractor()
        let source = math.extract(markdown)
        let byteCount = source.utf8.count
        let output = source.withCString { bytes in
            cgfm_render_html(bytes, byteCount, includeSourcePositions ? 1 : 0)
        }
        guard let output else {
            throw MarkdownRenderError.renderingFailed
        }
        defer { cgfm_free_html(output) }
        guard let html = String(validatingCString: output) else {
            throw MarkdownRenderError.invalidOutput
        }
        // Math is restored before heading ids, so a formula in a heading is slugged
        // from its TeX text rather than from the placeholder token.
        return DiagramBlocks.convert(HeadingAnchors.addingIDs(to: math.restore(html)))
    }
}

/// Turns ```math and ```mermaid code blocks into elements the preview scripts render.
/// The code text is already HTML-escaped by cmark and is kept as-is.
enum DiagramBlocks {
    private static let block = try! NSRegularExpression(
        pattern: "<pre(?: [^>]*)?><code class=\"language-(math|mermaid)\">(.*?)</code></pre>",
        options: [.dotMatchesLineSeparators]
    )

    static func convert(_ html: String) -> String {
        guard html.contains("language-math") || html.contains("language-mermaid") else { return html }
        let source = html as NSString
        var result = ""
        var copied = 0
        for match in block.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let kind = source.substring(with: match.range(at: 1))
            let body = source.substring(with: match.range(at: 2))
            let element = kind == "math"
                ? "<div class=\"maro-math\" data-display=\"block\">\(body)</div>"
                : "<div class=\"maro-mermaid\">\(body)</div>"
            result += source.substring(with: NSRange(location: copied, length: match.range.location - copied))
            result += element
            copied = NSMaxRange(match.range)
        }
        result += source.substring(from: copied)
        return result
    }
}

/// Gives headings the same `id` slugs that GitHub uses for `#fragment` links.
public enum HeadingAnchors {
    /// Like GitHub, heading ids carry this prefix so they cannot collide with the page's
    /// own ids or footnote ids; `#slug` links resolve to `user-content-slug`.
    public static let idPrefix = "user-content-"

    // Safe only because cmark-gfm runs without CMARK_OPT_UNSAFE: raw HTML is omitted and
    // code text is escaped, so a literal `<hN` can only come from a real heading.
    // Enabling unsafe HTML would break this assumption.
    private static let heading = try! NSRegularExpression(
        pattern: "<h([1-6])((?: [^>]*)?)>(.*?)</h\\1>",
        options: [.dotMatchesLineSeparators]
    )
    private static let tag = try! NSRegularExpression(pattern: "<[^>]*>")

    static func addingIDs(to html: String) -> String {
        let source = html as NSString
        let matches = heading.matches(in: html, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return html }

        // One forward pass: slugs are assigned in document order (duplicates get -1, -2
        // like GitHub), and the HTML is copied once instead of shifted per heading.
        var slugger = Slugger()
        var result = ""
        result.reserveCapacity(html.utf8.count + matches.count * 32)
        var copied = 0
        for match in matches {
            let slug = slugger.slug(plainText(source.substring(with: match.range(at: 3))))
            // Slugs keep only letters, marks, digits, connector punctuation, and "-",
            // so they never contain characters that need HTML escaping.
            guard !slug.isEmpty else { continue }
            let insertion = match.range(at: 2).location
            result += source.substring(with: NSRange(location: copied, length: insertion - copied))
            result += " id=\"\(idPrefix)\(slug)\""
            copied = insertion
        }
        result += source.substring(from: copied)
        return result
    }

    static func plainText(_ fragment: String) -> String {
        let stripped = tag.stringByReplacingMatches(
            in: fragment,
            range: NSRange(location: 0, length: (fragment as NSString).length),
            withTemplate: ""
        )
        // cmark-gfm escapes only these characters in text content.
        return stripped
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

/// GitHub's heading slug algorithm (github-slugger), with the character rule
/// measured against GitHub's Markdown API rather than taken from github-slugger's table.
struct Slugger {
    // Keyed by scalars, not String: Swift's String equality treats NFC and NFD as equal,
    // but GitHub gives "café" and "cafe\u{301}" separate slugs without a -1 suffix.
    private var occurrences: [[Unicode.Scalar]: Int] = [:]

    mutating func slug(_ value: String) -> String {
        let original = Array(Self.slug(value).unicodeScalars)
        var result = original
        while occurrences[result] != nil {
            occurrences[original, default: 0] += 1
            result = original + "-\(occurrences[original]!)".unicodeScalars
        }
        occurrences[result] = 0
        var view = String.UnicodeScalarView()
        view.append(contentsOf: result)
        return String(view)
    }

    static func slug(_ value: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in value.lowercased().unicodeScalars where isKept(scalar) {
            scalars.append(scalar == " " ? "-" : scalar)
        }
        return String(scalars)
    }

    /// GitHub keeps alphabetic characters (which includes circled and squared Latin
    /// letters), marks, digits, connector punctuation, ZWNJ/ZWJ, "-" and spaces.
    private static func isKept(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == " " || scalar == "-" { return true }
        let properties = scalar.properties
        if properties.isAlphabetic || properties.isJoinControl { return true }
        switch properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .connectorPunctuation:
            return true
        default:
            return false
        }
    }
}
