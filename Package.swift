// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MaroMarkdown",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "MaroMarkdown", targets: ["MaroMarkdown"])
    ],
    targets: [
        .target(
            name: "CGFM",
            publicHeadersPath: "include",
            linkerSettings: [.linkedLibrary("cmark-gfm")]
        ),
        .executableTarget(
            name: "MaroMarkdown",
            dependencies: ["CGFM"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MaroMarkdownTests",
            dependencies: ["MaroMarkdown"]
        )
    ]
)
