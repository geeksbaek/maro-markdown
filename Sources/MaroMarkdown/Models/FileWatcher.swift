import Foundation

/// Reports changes to the file at one path.
///
/// Many editors save by writing a new file and renaming it over the old one,
/// which leaves a watched descriptor pointing at the deleted file. When the
/// watched file is deleted, renamed or revoked, the watcher opens the path
/// again and reports a change once the new file is there.
enum FileWatcher {
    static func changes(at url: URL) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let watcher = PathWatcher(path: url.path) { continuation.yield() }
            continuation.onTermination = { _ in watcher.stop() }
            watcher.start()
        }
    }
}

/// All state is touched only on `queue`.
private final class PathWatcher: @unchecked Sendable {
    private let path: String
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "io.github.geeksbaek.maromarkdown.file-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var stopped = false

    init(path: String, onChange: @escaping @Sendable () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        queue.async { self.attach(reportOnAttach: false) }
    }

    func stop() {
        queue.async {
            self.stopped = true
            self.source?.cancel()
            self.source = nil
        }
    }

    private func attach(reportOnAttach: Bool) {
        guard !stopped, source == nil else { return }
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            // The replacement file is not in place yet, or the file is gone.
            queue.asyncAfter(deadline: .now() + .milliseconds(300)) {
                self.attach(reportOnAttach: reportOnAttach)
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self, unowned source] in
            guard let self else { return }
            if source.data.isDisjoint(with: [.delete, .rename, .revoke]) {
                self.onChange()
            } else {
                source.cancel()
                self.source = nil
                self.queue.asyncAfter(deadline: .now() + .milliseconds(50)) {
                    self.attach(reportOnAttach: true)
                }
            }
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
        if reportOnAttach {
            onChange()
        }
    }
}
