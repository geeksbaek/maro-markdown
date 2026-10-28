# Maro Markdown

English | [한국어](README.ko.md)

A native macOS Markdown editor and viewer that renders GitHub Flavored Markdown the way GitHub does, with careful handling of Korean, Japanese, and Chinese text.

- Edit, side-by-side, and preview modes
- GitHub Flavored Markdown: tables, task lists, strikethrough, autolinks, footnotes
- GitHub alerts (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`)
- Heading anchors with the same ids GitHub generates, so `#heading` links work
- Math with GitHub's syntax (`$…$`, `` $`…`$ ``, `$$…$$`, ```` ```math ````), rendered by KaTeX
- Mermaid diagrams in ```` ```mermaid ```` blocks, following light and dark mode
- GitHub's Markdown stylesheet, in light and dark mode
- Finder Quick Look preview: press Space on a `.md` file to see it rendered, math and diagrams included
- Input method composition (Korean, Japanese, Chinese) is committed before a mode switch or window close, so no characters are lost
- Preserves the file's encoding on save (UTF-8, UTF-8 with BOM, UTF-16 LE/BE)

Rendering happens locally with the `libcmark-gfm` that ships with macOS, plus bundled copies of KaTeX and Mermaid. Documents are never sent anywhere, and scripts inside a document never run: the preview blocks all page scripts and the app injects only its own bundled ones.

## Requirements

- macOS 27 or later (the app links the system `libcmark-gfm`)
- Apple Silicon (arm64)

## Install

Download `Maro-Markdown.zip` from [Releases](https://github.com/geeksbaek/maro-markdown/releases), unzip it, and move `Maro Markdown.app` to `/Applications`.

The app is not signed with an Apple Developer ID or notarized, so macOS blocks the first launch with an "unidentified developer" warning. Open it in one of these ways:

- In Finder, **right-click the app → Open**, then click **Open** in the warning.
- Or remove the download quarantine flag in Terminal:

  ```sh
  xattr -dr com.apple.quarantine "/Applications/Maro Markdown.app"
  ```

## Build from source

Requires the Xcode command line tools with Swift 6.

```sh
MARO_BUILD_CONFIGURATION=release script/build_and_run.sh --build-only
ditto "dist/Maro Markdown.app" "/Applications/Maro Markdown.app"
```

The script builds with SwiftPM, assembles the app bundle and its Quick Look extension, and signs both ad hoc. Run it without `--build-only` to launch the development build. A locally built app has no quarantine flag, so it opens without the warning above.

To make Maro Markdown the default app for `.md` files, select a Markdown file in Finder, choose **Get Info → Open with → Maro Markdown**, and click **Change All…**.

If Quick Look still shows plain text or only a file-info card after installing or updating, reset its cache and restart Finder, which remembers the previous result:

```sh
qlmanage -r && qlmanage -r cache && killall Finder
```

and check that Maro Markdown is enabled in **System Settings → General → Login Items & Extensions → Quick Look**.

## Test

```sh
swift test
```

The tests cover the renderer, GitHub alert conversion, heading ids (including 54 cases captured from GitHub's Markdown API), math and diagram extraction, an offscreen WebKit check that math and Mermaid render while page scripts stay blocked, text encodings, input method composition in the editor, and the image handling of the Quick Look page.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Bold | ⌘B |
| Italic | ⌘I |
| Inline code | ⌘E |
| Link | ⌘K |
| Heading | ⌥⌘2 |
| Find | ⌘F |

## Known differences from GitHub

- Not rendered: syntax highlighting, emoji shortcodes (`:smile:`), GeoJSON/TopoJSON/STL blocks, and GitHub references such as `#123` and `@user`.
- Math uses KaTeX, while GitHub uses MathJax, so a few rarely used TeX commands may differ.
- Raw HTML is not rendered, including tags GitHub allows such as `<details>` and `<kbd>`.
- Alert titles and heading links have no Octicon icons.

## Known limitations

- **Quick Look shows images as placeholders.** The Quick Look extension is sandboxed: it can read only the Markdown file itself, and a page that references a remote image never finishes loading there. So the Space-bar preview shows each image's alt text in its place. Images display normally in the app.
- The Quick Look extension has the network-client entitlement only because WebKit needs it to start inside the sandbox. The preview page loads nothing from the network.
- Files larger than 4 MB are truncated in the Quick Look preview.
- No Developer ID signature or notarization; see Install above.

## License

MIT. See [LICENSE](LICENSE). Bundled third-party code and its licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
