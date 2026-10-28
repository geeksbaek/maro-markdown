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
        let byteCount = markdown.utf8.count
        let output = markdown.withCString { bytes in
            cgfm_render_html(bytes, byteCount, includeSourcePositions ? 1 : 0)
        }
        guard let output else {
            throw MarkdownRenderError.renderingFailed
        }
        defer { cgfm_free_html(output) }
        guard let html = String(validatingCString: output) else {
            throw MarkdownRenderError.invalidOutput
        }
        return HeadingAnchors.addingIDs(to: html)
    }
}

/// Gives headings the same `id` slugs that GitHub uses for `#fragment` links.
enum HeadingAnchors {
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
            result += " id=\"\(slug)\""
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

/// Port of github-slugger 2.0.0, the slug algorithm GitHub uses for heading anchors.
struct Slugger {
    private var occurrences: [String: Int] = [:]

    mutating func slug(_ value: String) -> String {
        let original = Self.slug(value)
        var result = original
        while occurrences[result] != nil {
            occurrences[original, default: 0] += 1
            result = "\(original)-\(occurrences[original]!)"
        }
        occurrences[result] = 0
        return result
    }

    static func slug(_ value: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in value.lowercased().unicodeScalars where isKept(scalar) {
            scalars.append(scalar == " " ? "-" : scalar)
        }
        return String(scalars)
    }

    private static func isKept(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == " " || scalar == "-" { return true }
        // Circled Latin letters are symbols that github-slugger still keeps.
        if (0x24B6...0x24E9).contains(scalar.value) { return true }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark,
             .decimalNumber, .letterNumber, .connectorPunctuation:
            return true
        default:
            return false
        }
    }
}
