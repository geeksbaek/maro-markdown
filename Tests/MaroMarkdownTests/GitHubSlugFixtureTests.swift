import XCTest
@testable import MaroRenderer

/// Heading ids captured from GitHub's Markdown API (markdown mode) on 2026-10-28.
/// Each pair is (heading text, id without the user-content- prefix, "" when GitHub emits none).
final class GitHubSlugFixtureTests: XCTestCase {
    private let cases: [(String, String)] = [
        ("rocket \u{1F680}", "rocket-"),
        ("sq-A \u{1F170}", "sq-a-\u{1F170}"),
        ("circled-A \u{24B6}", "circled-a-\u{24D0}"),
        ("U+0870 \u{870}", "u0870-\u{870}"),
        ("U+1AC1 a\u{1AC1}", "u1ac1-a\u{1AC1}"),
        ("U+10570 \u{10570}", "u10570-\u{10597}"),
        ("sigma \u{39F}\u{394}\u{39F}\u{3A3}", "sigma-\u{3BF}\u{3B4}\u{3BF}\u{3C3}"),
        ("nfd cafe\u{301}", "nfd-cafe\u{301}"),
        ("nfc caf\u{E9}", "nfc-caf\u{E9}"),
        ("tm \u{2122}", "tm-"),
        ("super2 x\u{B2}", "super2-x"),
        ("roman \u{216B}", "roman-\u{217B}"),
        ("han-ext \u{20000}", "han-ext-\u{20000}"),
        ("emoji-zwj \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}", "emoji-zwj-\u{200D}\u{200D}"),
        ("flag \u{1F1F0}\u{1F1F7}", "flag-"),
        ("keycap 1\u{FE0F}\u{20E3}", "keycap-1\u{FE0F}\u{20E3}"),
        ("fullwidth \u{FF21}\u{FF22}", "fullwidth-\u{FF41}\u{FF42}"),
        ("halfwidth-kana \u{FF71}\u{FF72}", "halfwidth-kana-\u{FF71}\u{FF72}"),
        ("cjk-punct \u{300C}\u{C778}\u{C6A9}\u{300D}", "cjk-punct-\u{C778}\u{C6A9}"),
        ("middle-dot \u{AC00}\u{B7}\u{B098}", "middle-dot-\u{AC00}\u{B098}"),
        ("p200C a\u{200C}b", "p200c-a\u{200C}b"),
        ("p200D a\u{200D}b", "p200d-a\u{200D}b"),
        ("p200B a\u{200B}b", "p200b-ab"),
        ("p200E a\u{200E}b", "p200e-ab"),
        ("p2060 a\u{2060}b", "p2060-ab"),
        ("pFEFF a\u{FEFF}b", "pfeff-ab"),
        ("pAD a\u{AD}b", "pad-ab"),
        ("p2061 a\u{2061}b", "p2061-ab"),
        ("p1F12F a\u{1F12F}b", "p1f12f-ab"),
        ("p1F130 a\u{1F130}b", "p1f130-a\u{1F130}b"),
        ("p1F149 a\u{1F149}b", "p1f149-a\u{1F149}b"),
        ("p1F14A a\u{1F14A}b", "p1f14a-ab"),
        ("p1F150 a\u{1F150}b", "p1f150-a\u{1F150}b"),
        ("p1F169 a\u{1F169}b", "p1f169-a\u{1F169}b"),
        ("p1F16A a\u{1F16A}b", "p1f16a-ab"),
        ("p1F170 a\u{1F170}b", "p1f170-a\u{1F170}b"),
        ("p1F189 a\u{1F189}b", "p1f189-a\u{1F189}b"),
        ("p1F18A a\u{1F18A}b", "p1f18a-ab"),
        ("p24B5 a\u{24B5}b", "p24b5-ab"),
        ("p24B6 a\u{24B6}b", "p24b6-a\u{24D0}b"),
        ("p24E9 a\u{24E9}b", "p24e9-a\u{24E9}b"),
        ("p24EA a\u{24EA}b", "p24ea-ab"),
        ("p2460 a\u{2460}b", "p2460-ab"),
        ("p3248 a\u{3248}b", "p3248-ab"),
        ("p1F100 a\u{1F100}b", "p1f100-ab"),
        ("p1F10B a\u{1F10B}b", "p1f10b-ab"),
        ("p1F1E6 a\u{1F1E6}b", "p1f1e6-ab"),
        ("pE0041 a\u{E0041}b", "pe0041-ab"),
        ("caf\u{E9}", "caf\u{E9}"),
        ("cafe\u{301}", "cafe\u{301}"),
        ("\u{D55C}\u{AE00}", "\u{D55C}\u{AE00}"),
        ("\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}", "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}"),
        ("\u{1F680}", ""),
        ("\u{1F680}", "-1"),
    ]

    func testSlugsMatchGitHub() {
        var slugger = Slugger()
        for (heading, expected) in cases {
            XCTAssertEqual(slugger.slug(heading), expected, heading)
        }
    }
}
