import Foundation

/// Pulls TeX math out of Markdown source before cmark sees it, following GitHub's math syntax:
/// `$…$` and `` $`…`$ `` inline, `$$…$$` as a block. Code spans and fenced code are skipped,
/// and `\$` stays a literal dollar sign.
///
/// Each formula becomes an alphanumeric placeholder that cmark passes through unchanged,
/// and `restore` swaps the placeholders in the rendered HTML for escaped math elements.
struct MathExtractor {
    struct Formula {
        let tex: String
        let display: Bool
    }

    private(set) var formulas: [Formula] = []
    /// Random per render, so document text cannot forge a placeholder.
    private let token = "MAROMATH" + UUID().uuidString.replacingOccurrences(of: "-", with: "")

    mutating func extract(_ markdown: String) -> String {
        guard markdown.contains("$") else { return markdown }
        let chars = Array(markdown)
        var output = ""
        output.reserveCapacity(markdown.utf8.count)
        var index = 0
        var lineStart = true
        var fence: (char: Character, count: Int)?

        while index < chars.count {
            if lineStart, let marker = fenceMarker(chars, at: index) {
                if let open = fence {
                    if marker.char == open.char, marker.count >= open.count { fence = nil }
                } else {
                    fence = marker
                }
            }
            if fence != nil {
                let end = lineEnd(chars, from: index)
                output.append(contentsOf: chars[index..<end])
                index = end
                lineStart = true
                continue
            }

            let char = chars[index]
            lineStart = char == "\n"

            if char == "\\", index + 1 < chars.count {
                output.append(char)
                output.append(chars[index + 1])
                lineStart = chars[index + 1] == "\n"
                index += 2
                continue
            }
            if char == "`" {
                let end = codeSpanEnd(chars, from: index)
                output.append(contentsOf: chars[index..<end])
                index = end
                continue
            }
            if char == "$", let match = formula(chars, at: index) {
                output += placeholder(for: Formula(tex: match.tex, display: match.display))
                index = match.end
                continue
            }
            output.append(char)
            index += 1
        }
        return output
    }

    func restore(_ html: String) -> String {
        guard !formulas.isEmpty else { return html }
        var result = html
        for (number, formula) in formulas.enumerated().reversed() {
            let key = "\(token)X\(number)Z"
            let element = formula.display
                ? "<div class=\"maro-math\" data-display=\"block\">\(escapeHTML(formula.tex))</div>"
                : "<span class=\"maro-math\" data-display=\"inline\">\(escapeHTML(formula.tex))</span>"
            // A block formula on its own line is wrapped in <p> by cmark; drop it so the
            // display element is not nested inside a paragraph.
            if formula.display {
                result = result.replacingOccurrences(of: "<p>\(key)</p>", with: element)
            }
            result = result.replacingOccurrences(of: key, with: element)
        }
        return result
    }

    private mutating func placeholder(for formula: Formula) -> String {
        formulas.append(formula)
        return "\(token)X\(formulas.count - 1)Z"
    }

    // MARK: - Scanning

    private func formula(_ chars: [Character], at index: Int) -> (tex: String, display: Bool, end: Int)? {
        let next = index + 1 < chars.count ? chars[index + 1] : nil

        if next == "$" {
            // $$…$$ display math; may span lines but not a blank line.
            var cursor = index + 2
            while cursor + 1 < chars.count {
                if chars[cursor] == "\\" { cursor += 2; continue }
                if chars[cursor] == "\n", cursor + 1 < chars.count, isBlankLine(chars, from: cursor + 1) { return nil }
                if chars[cursor] == "$", chars[cursor + 1] == "$" {
                    let tex = String(chars[(index + 2)..<cursor]).trimmingCharacters(in: .whitespacesAndNewlines)
                    return tex.isEmpty ? nil : (tex, true, cursor + 2)
                }
                cursor += 1
            }
            return nil
        }

        if next == "`" {
            // $`…`$ inline math, which tolerates spaces and dollar signs inside.
            var cursor = index + 2
            while cursor + 1 < chars.count, chars[cursor] != "\n" {
                if chars[cursor] == "`", chars[cursor + 1] == "$" {
                    let tex = String(chars[(index + 2)..<cursor])
                    return tex.isEmpty ? nil : (tex, false, cursor + 2)
                }
                cursor += 1
            }
            return nil
        }

        // $…$ inline math: no space just inside either dollar, and the closing dollar
        // must not be followed by a digit, so prices like "$5 and $10" stay text.
        // A backtick ends the search: the closing dollar is never inside a code span,
        // and TeX that needs backticks uses the $`…`$ form.
        guard let first = next, !first.isWhitespace else { return nil }
        var cursor = index + 1
        while cursor < chars.count, chars[cursor] != "\n", chars[cursor] != "`" {
            if chars[cursor] == "\\" { cursor += 2; continue }
            if chars[cursor] == "$" {
                let before = chars[cursor - 1]
                let after = cursor + 1 < chars.count ? chars[cursor + 1] : nil
                if before.isWhitespace || after?.isNumber == true { return nil }
                return (String(chars[(index + 1)..<cursor]), false, cursor + 1)
            }
            cursor += 1
        }
        return nil
    }

    private func fenceMarker(_ chars: [Character], at index: Int) -> (char: Character, count: Int)? {
        var cursor = index
        var indent = 0
        while cursor < chars.count, chars[cursor] == " ", indent < 4 { cursor += 1; indent += 1 }
        guard indent < 4, cursor < chars.count, chars[cursor] == "`" || chars[cursor] == "~" else { return nil }
        let mark = chars[cursor]
        var count = 0
        while cursor < chars.count, chars[cursor] == mark { cursor += 1; count += 1 }
        return count >= 3 ? (mark, count) : nil
    }

    private func codeSpanEnd(_ chars: [Character], from index: Int) -> Int {
        var run = 0
        var cursor = index
        while cursor < chars.count, chars[cursor] == "`" { run += 1; cursor += 1 }
        while cursor < chars.count {
            if chars[cursor] == "`" {
                var closing = 0
                while cursor < chars.count, chars[cursor] == "`" { closing += 1; cursor += 1 }
                if closing == run { return cursor }
            } else {
                cursor += 1
            }
        }
        // No closing run: the backticks are literal text.
        return index + run
    }

    private func lineEnd(_ chars: [Character], from index: Int) -> Int {
        var cursor = index
        while cursor < chars.count, chars[cursor] != "\n" { cursor += 1 }
        return min(cursor + 1, chars.count)
    }

    private func isBlankLine(_ chars: [Character], from index: Int) -> Bool {
        var cursor = index
        while cursor < chars.count, chars[cursor] != "\n" {
            if !chars[cursor].isWhitespace { return false }
            cursor += 1
        }
        return true
    }
}

func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
