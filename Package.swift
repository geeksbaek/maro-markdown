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
            resources: [.process("Resources")]
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
            linkerSettings: [.linkedFramework("QuickLookUI")]
        ),
        .testTarget(
            name: "MaroMarkdownTests",
            dependencies: ["MaroMarkdown", "MaroRenderer"]
        )
    ]
)
