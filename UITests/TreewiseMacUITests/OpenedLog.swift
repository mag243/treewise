import XCTest

/// Where a UI test's app notes a file it would open in another app (`-TreewiseOpenedLog`),
/// beside the test's folder, so no other app starts on the Mac the tests run on, and a test
/// that opens a file by mistake says so.
enum OpenedLog {
    /// The log of the app that runs in `root`.
    static func url(for root: URL) -> URL {
        root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent + ".opened")
    }

    /// The launch arguments that make the app note what it opens.
    static func arguments(for root: URL) -> [String] {
        ["-TreewiseOpenedLog", url(for: root).path]
    }

    /// What the app noted, one path a line, or nothing.
    static func opened(for root: URL) -> String {
        (try? String(contentsOf: url(for: root), encoding: .utf8)) ?? ""
    }

    /// Fails the test when the app opened a file in another app, and removes the log.
    static func check(root: URL, file: StaticString = #filePath, line: UInt = #line) {
        defer { try? FileManager.default.removeItem(at: url(for: root)) }
        let opened = opened(for: root)
        guard !opened.isEmpty else { return }
        XCTFail("Treewise opened a file in another app: \(opened)", file: file, line: line)
    }
}
