import XCTest
@testable import MaroRenderer

final class MathAndDiagramTests: XCTestCase {
    private func render(_ markdown: String) throws -> String {
        try MarkdownRenderer.renderHTML(markdown)
    }

    func testInlineAndBacktickMath() throws {
        let html = try render("면적은 $\\pi r^2$이고 $`a < b`$ 이다")
        XCTAssertTrue(html.contains("<span class=\"maro-math\" data-display=\"inline\">\\pi r^2</span>이고"))
        XCTAssertTrue(html.contains("<span class=\"maro-math\" data-display=\"inline\">a &lt; b</span>"))
    }

    func testDisplayMathIsNotWrappedInParagraph() throws {
        let html = try render("앞\n\n$$\nE = mc^2\n$$\n\n뒤")
        XCTAssertTrue(html.contains("<div class=\"maro-math\" data-display=\"block\">E = mc^2</div>"))
        XCTAssertFalse(html.contains("<p><div"))
    }

    func testDollarSignsThatAreNotMath() throws {
        let html = try render("""
        price $5 and $10 dollars

        escaped \\$x\\$ here

        code `$a$` span

        tight $ x $ space
        """)
        XCTAssertFalse(html.contains("maro-math"), html)
        XCTAssertTrue(html.contains("price $5 and $10 dollars"))
        XCTAssertTrue(html.contains("escaped $x$ here"))
        XCTAssertTrue(html.contains("<code>$a$</code>"))
    }

    func testFencedCodeKeepsDollarSigns() throws {
        let html = try render("```sh\necho $HOME $PATH\n```\n\n~~~\n$x$\n~~~")
        XCTAssertFalse(html.contains("maro-math"))
        XCTAssertTrue(html.contains("echo $HOME $PATH"))
    }

    func testMathBlockAndMermaidFences() throws {
        let html = try render("```math\n\\frac{a}{b} < 1\n```\n\n```mermaid\ngraph TD; A-->B\n```")
        XCTAssertTrue(html.contains("<div class=\"maro-math\" data-display=\"block\">\\frac{a}{b} &lt; 1\n</div>"))
        XCTAssertTrue(html.contains("<div class=\"maro-mermaid\">graph TD; A--&gt;B\n</div>"))
        XCTAssertFalse(html.contains("language-mermaid"))
    }

    func testMathInsideEmphasisAndHeading() throws {
        let html = try render("# 공식 $x^2$\n\n**$y$** 굵게")
        XCTAssertTrue(html.contains("<h1 id=\"user-content-공식-x2\">공식 <span class=\"maro-math\""), html)
        XCTAssertTrue(html.contains("<strong><span class=\"maro-math\" data-display=\"inline\">y</span></strong>"))
    }

    func testMathTextIsEscaped() throws {
        let html = try render("$<script>alert(1)</script>$")
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func testPlaceholderCannotBeForged() throws {
        // Document text that looks like a placeholder must stay text.
        let html = try render("MAROMATHX0Z and $a$")
        XCTAssertTrue(html.contains("MAROMATHX0Z and "))
    }
}
