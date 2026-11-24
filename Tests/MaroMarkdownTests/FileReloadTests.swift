import Foundation
import XCTest
@testable import MaroMarkdown

final class FileReloadTests: XCTestCase {
    func testDiskChangeDecision() {
        let saved = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)

        XCTAssertEqual(
            DiskChange.decide(diskText: "a", windowText: "a", diskDate: later,
                              lastSaveDate: saved, hasUnsavedEdits: true),
            .upToDate
        )
        // Another app changed the file and the window is clean.
        XCTAssertEqual(
            DiskChange.decide(diskText: "b", windowText: "a", diskDate: later,
                              lastSaveDate: saved, hasUnsavedEdits: false),
            .reload
        )
        // Another app changed the file while the window has unsaved edits.
        XCTAssertEqual(
            DiskChange.decide(diskText: "b", windowText: "a", diskDate: later,
                              lastSaveDate: saved, hasUnsavedEdits: true),
            .conflict
        )
        // The file holds this window's last save and the window was edited since.
        XCTAssertEqual(
            DiskChange.decide(diskText: "a", windowText: "ab", diskDate: saved,
                              lastSaveDate: saved, hasUnsavedEdits: true),
            .ownSave
        )
        XCTAssertEqual(
            DiskChange.decide(diskText: "b", windowText: "a", diskDate: later,
                              lastSaveDate: saved, hasUnsavedEdits: true, discardingEdits: true),
            .reload
        )
    }

    func testWatcherReportsInPlaceWritesAndReplacements() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileReloadTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("doc.md")
        try Data("one".utf8).write(to: file)

        let counter = Counter()
        let watching = Task {
            for await _ in FileWatcher.changes(at: file) {
                await counter.increment()
            }
        }
        defer { watching.cancel() }
        try await Task.sleep(for: .milliseconds(300))
        let initial = await counter.value
        XCTAssertEqual(initial, 0, "opening the file is not a change")

        // Writing into the same file.
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(" two".utf8))
        try handle.close()
        try await expectChange(after: initial, counter, "in-place write")

        // Saving by replacing the file, twice, so the watcher must follow
        // the path to each new file.
        for round in 1...2 {
            try await Task.sleep(for: .milliseconds(400))
            let before = await counter.value
            try Data("replaced \(round)".utf8).write(to: file, options: .atomic)
            try await expectChange(after: before, counter, "replacement \(round)")
        }
    }

    private actor Counter {
        private(set) var value = 0
        func increment() { value += 1 }
    }

    private func expectChange(after count: Int, _ counter: Counter, _ label: String) async throws {
        for _ in 0..<30 {
            if await counter.value > count { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("No change reported for \(label)")
    }
}
