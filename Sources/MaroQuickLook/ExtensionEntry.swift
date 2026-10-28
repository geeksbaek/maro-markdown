import Foundation

// App extensions start in NSExtensionMain, which loads NSExtensionPrincipalClass
// from the .appex Info.plist. Foundation exports it without a Swift declaration.
@_silgen_name("NSExtensionMain")
private func NSExtensionMain(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> Int32

@main
enum ExtensionEntry {
    static func main() {
        // Referencing the controller keeps its Objective-C class linked for lookup by name.
        _ = PreviewViewController.self
        exit(NSExtensionMain(CommandLine.argc, CommandLine.unsafeArgv))
    }
}
