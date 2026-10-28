import Foundation
import MaroRenderer
import QuickLookUI
import UniformTypeIdentifiers

/// Renders Markdown for Finder's Quick Look (space bar) with the app's renderer and styles.
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    // Quick Look only needs a readable preview, so very large files are cut off.
    private static let maximumBytes = 4 * 1024 * 1024
    private static let maximumImageBytes = 16 * 1024 * 1024

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let data = try Data(contentsOf: request.fileURL, options: .mappedIfSafe)
        let text = SourceEncoding.decodeLossily(data.prefix(Self.maximumBytes))
        let body = try MarkdownRenderer.renderHTML(text)
        let images = Self.attachLocalImages(in: body, relativeTo: request.fileURL.deletingLastPathComponent())
        let page = PreviewPage.shell(content: images.html)

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1100)) { _ in
            Data(page.utf8)
        }
        reply.stringEncoding = .utf8
        reply.title = request.fileURL.lastPathComponent
        reply.attachments = images.attachments
        return reply
    }

    /// Quick Look serves the page from an internal origin, so relative image paths cannot
    /// resolve. Images inside the document's folder are attached and referenced by cid:.
    private static func attachLocalImages(
        in html: String,
        relativeTo folder: URL
    ) -> (html: String, attachments: [String: QLPreviewReplyAttachment]) {
        let rewritten = LocalImages.rewrite(html, relativeTo: folder)
        var attachments: [String: QLPreviewReplyAttachment] = [:]
        for file in rewritten.files {
            guard let type = UTType(filenameExtension: file.url.pathExtension), type.conforms(to: .image),
                  let size = try? file.url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= maximumImageBytes,
                  let data = try? Data(contentsOf: file.url) else { continue }
            attachments[file.identifier] = QLPreviewReplyAttachment(data: data, contentType: type)
        }
        return (rewritten.html, attachments)
    }
}
