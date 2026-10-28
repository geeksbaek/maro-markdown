// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MaroMarkdown",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "MaroMarkdown", targets: ["MaroMarkdown"]),
        .executable(name: "MaroQuickLook", targets: ["MaroQuickLook"])
    ],
    targets: [
        .target(
            name: "CGFM",
            publicHeadersPath: "include",
            linkerSettings: [.linkedLibrary("cmark-gfm")]
        ),
        .target(
            name: "MaroRenderer",
            dependencies: ["CGFM"],
            resources: [
                .process("Resources/github-markdown.css"),
                // KaTeX, Mermaid and the preview renderer, kept as-is with their folder layout.
                .copy("Resources/vendor")
            ],
            linkerSettings: [.linkedFramework("WebKit")]
        ),
        .executableTarget(
            name: "MaroMarkdown",
            dependencies: ["MaroRenderer"],
            resources: [.process("Resources")]
        ),
        // Quick Look preview extension. script/build_and_run.sh wraps the
        // executable in an .appex inside the app bundle.
        .executableTarget(
            name: "MaroQuickLook",
            dependencies: ["MaroRenderer"],
            exclude: ["MaroQuickLook.entitlements"],
            linkerSettings: [.linkedFramework("QuickLookUI"), .linkedFramework("WebKit")]
        ),
        .testTarget(
            name: "MaroMarkdownTests",
            dependencies: ["MaroMarkdown", "MaroRenderer"]
        )
    ]
)
