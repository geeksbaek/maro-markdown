import XCTest
@testable import MaroRenderer

final class MarkdownRendererTests: XCTestCase {
    func testCJKEmphasisAndGFMExtensions() throws {
        let source = """
        **강조**는 한국어입니다. 中文**重点**，日本語の**強調**。

        | 항목 | 값 |
        | :--- | ---: |
        | 한글 | 42 |

        - [x] 완료
        - [ ] 진행 중

        ~~취소~~ https://example.com
        """
        let html = try MarkdownRenderer.renderHTML(source)
        XCTAssertTrue(html.contains("<strong>강조</strong>는"))
        XCTAssertTrue(html.contains("<strong>重点</strong>，"))
        XCTAssertTrue(html.contains("<strong>強調</strong>"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<td align=\"right\">42</td>"))
        XCTAssertTrue(html.contains("type=\"checkbox\""))
        XCTAssertTrue(html.contains("<del>취소</del>"))
        XCTAssertTrue(html.contains("href=\"https://example.com\""))
    }

    func testUnsafeHTMLAndURLsStayInert() throws {
        let html = try MarkdownRenderer.renderHTML(
            "[위험](javascript:alert(1)) <script>alert(1)</script> ![이미지](data:text/html,evil)"
        )
        XCTAssertFalse(html.contains("href=\"javascript:"))
        XCTAssertFalse(html.contains("src=\"data:text/html"))
        XCTAssertFalse(html.contains("<script>"))
    }

    func testEmojiAndFootnoteRemainValidUTF8() throws {
        let html = try MarkdownRenderer.renderHTML("# 제목 🧭\n\n각주[^메모]\n\n[^메모]: 설명")
        XCTAssertTrue(html.contains("제목 🧭"))
        XCTAssertTrue(html.contains("설명"))
        XCTAssertTrue(html.contains("footnote"))
    }

    func testHeadingIDsFollowGitHubSlugRules() throws {
        let html = try MarkdownRenderer.renderHTML("""
        # 제목 🧭
        ## A & B `code`
        ### 中文 見出し
        ## 제목 🧭
        ## 제목 🧭
        ## Ⓐ_x – y!
        # 🚀

        [이동](#제목-)
        """)
        XCTAssertTrue(html.contains("<h1 id=\"제목-\">제목 🧭</h1>"))
        XCTAssertTrue(html.contains("<h2 id=\"a--b-code\">"))
        XCTAssertTrue(html.contains("<h3 id=\"中文-見出し\">"))
        XCTAssertTrue(html.contains("<h2 id=\"제목--1\">"))
        XCTAssertTrue(html.contains("<h2 id=\"제목--2\">"))
        XCTAssertTrue(html.contains("<h2 id=\"ⓐ_x--y\">"))
        XCTAssertTrue(html.contains("<h1>🚀</h1>"))
        // The preview percent-decodes the fragment before looking up the id.
        XCTAssertTrue(html.contains("href=\"#%EC%A0%9C%EB%AA%A9-\""))
    }

    // Expected ids were captured from GitHub's Markdown API (markdown mode) on 2026-10-28.
    func testHeadingIDsMatchGitHubForEmptyLinkAndImageHeadings() throws {
        let html = try MarkdownRenderer.renderHTML("""
        # 🚀

        # 🚀

        ## [링크](https://example.com) 제목

        ## ![그림](a.png) 이미지
        """)
        XCTAssertTrue(html.contains("<h1>🚀</h1>"))
        XCTAssertTrue(html.contains("<h1 id=\"-1\">🚀</h1>"))
        XCTAssertTrue(html.contains("<h2 id=\"링크-제목\">"))
        XCTAssertTrue(html.contains("<h2 id=\"-이미지\">"))
    }

    func testHeadingIDsWithSourcePositions() throws {
        let html = try MarkdownRenderer.renderHTML("# 한글", includeSourcePositions: true)
        XCTAssertTrue(html.contains("<h1 id=\"한글\" data-sourcepos=\"1:1-1:8\">한글</h1>"))
    }

    func testSluggerMatchesGitHubSluggerCases() {
        var slugger = Slugger()
        XCTAssertEqual(slugger.slug("Hello World"), "hello-world")
        XCTAssertEqual(slugger.slug("Hello World"), "hello-world-1")
        XCTAssertEqual(slugger.slug("hello-world"), "hello-world-2")
        XCTAssertEqual(Slugger.slug("<not a tag> & \"quotes\""), "not-a-tag--quotes")
        XCTAssertEqual(Slugger.slug("Привет мир"), "привет-мир")
        XCTAssertEqual(Slugger.slug("日本語のテスト。"), "日本語のテスト")
        XCTAssertEqual(Slugger.slug("1.2.3 버전"), "123-버전")
    }

    func testGitHubAlerts() throws {
        let html = try MarkdownRenderer.renderHTML("""
        > [!NOTE]
        > 참고 **내용**

        > [!warning]
        >
        > 둘째 문단

        > [!TIP] 같은 줄
        > 일반 인용

        > [!CAUTION]

        - > [!NOTE]
          > 목록 안

        > [!IMPORTANT]\u{20}\u{20}
        > 강제 줄바꿈
        """)
        XCTAssertTrue(html.contains("""
        <div class="markdown-alert markdown-alert-note">
        <p class="markdown-alert-title">Note</p>
        <p>참고 <strong>내용</strong></p>
        </div>
        """))
        XCTAssertTrue(html.contains("markdown-alert-warning"))
        XCTAssertTrue(html.contains("<p>둘째 문단</p>"))
        XCTAssertTrue(html.contains("<p>[!TIP] 같은 줄"))
        XCTAssertTrue(html.contains("<p>[!CAUTION]</p>"))
        XCTAssertFalse(html.contains("markdown-alert-tip"))
        XCTAssertFalse(html.contains("markdown-alert-caution"))
        // Matched against GitHub's Markdown API (gfm mode) on 2026-10-28.
        XCTAssertTrue(html.contains("<p>[!NOTE]\n목록 안</p>"))
        XCTAssertTrue(html.contains("""
        <div class="markdown-alert markdown-alert-important">
        <p class="markdown-alert-title">Important</p>
        <p>강제 줄바꿈</p>
        """))
    }
}
