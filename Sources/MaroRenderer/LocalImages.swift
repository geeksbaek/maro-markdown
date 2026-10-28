import Foundation

/// Finds `<img>` sources that point at files inside a document's folder and rewrites
/// them, for previews that cannot load relative paths themselves (Quick Look).
public enum LocalImages {
    private static let imageSource = try! NSRegularExpression(pattern: "(<img src=\")([^\"]*)(\")")

    /// Replaces each local image source with `cid:<identifier>` and returns the files to attach.
    /// Sources with a URL scheme, absolute paths, and paths leaving `folder` are left unchanged.
    public static func rewrite(
        _ html: String,
        relativeTo folder: URL
    ) -> (html: String, files: [(identifier: String, url: URL)]) {
        let source = html as NSString
        let root = folder.standardizedFileURL.path + "/"
        var files: [(identifier: String, url: URL)] = []
        var identifiers: [String: String] = [:]
        var result = ""
        var copied = 0

        for match in imageSource.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let valueRange = match.range(at: 2)
            guard let url = localURL(for: source.substring(with: valueRange), under: folder, root: root) else {
                continue
            }
            let identifier: String
            if let existing = identifiers[url.path] {
                identifier = existing
            } else {
                identifier = "img\(files.count)"
                identifiers[url.path] = identifier
                files.append((identifier, url))
            }
            result += source.substring(with: NSRange(location: copied, length: valueRange.location - copied))
            result += "cid:" + identifier
            copied = NSMaxRange(valueRange)
        }
        result += source.substring(from: copied)
        return (result, files)
    }

    static func localURL(for value: String, under folder: URL, root: String) -> URL? {
        // cmark escapes & in attributes; undo it before treating the value as a path.
        let raw = value.replacingOccurrences(of: "&amp;", with: "&")
        guard !raw.isEmpty, !raw.hasPrefix("/"), !raw.hasPrefix("#"),
              URL(string: raw)?.scheme == nil else { return nil }
        let pathPart = raw.split(separator: "?", maxSplits: 1).first.map(String.init) ?? raw
        let decoded = pathPart.removingPercentEncoding ?? pathPart
        let url = folder.appendingPathComponent(decoded).standardizedFileURL
        return url.path.hasPrefix(root) ? url : nil
    }
}
