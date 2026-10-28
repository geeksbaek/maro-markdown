import Foundation
import MaroRenderer
import QuickLookUI
import UniformTypeIdentifiers

/// Renders Markdown for Finder's Quick Look (space bar) with the app's renderer and styles.
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    // Quick Look only needs a readable preview, so very large files are cut off.
    private static let maximumBytes = 4 * 1024 * 1024

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let data = try Data(contentsOf: request.fileURL, options: .mappedIfSafe)
        let text = SourceEncoding.decodeLossily(data.prefix(Self.maximumBytes))
        let body = try MarkdownRenderer.renderHTML(text)
        let page = PreviewPage.shell(content: body)

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1100)) { _ in
            Data(page.utf8)
        }
        reply.stringEncoding = .utf8
        reply.title = request.fileURL.lastPathComponent
        return reply
    }
}
