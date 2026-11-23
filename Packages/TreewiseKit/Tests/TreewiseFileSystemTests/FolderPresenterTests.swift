import Foundation
import Synchronization
import Testing
import TreewiseFileSystem
import TreewiseTestSupport

extension FilePresenterSuites {
    /// A folder's changes as the system reports them to a file presenter, which is how a
    /// cloud provider's changes reach other apps on the iPad (ADR 0120).
    @Suite struct FolderPresenterTests {
        /// How long a change may take to arrive. Generous: on a busy runner the presenter is
        /// registered some time after it is added.
        private static let deadline = Duration.seconds(10)
        /// How often a file is written again while waiting.
        private static let pollInterval = Duration.milliseconds(100)

        /// What a wait for the presenter to hear of a write came to.
        private struct Report {
            /// The changes the presenter reported.
            let changes: Int
            /// The files written while waiting.
            let written: Int
            /// Whether the system still listed the presenter at the end.
            let isRegistered: Bool
        }

        /// Presents `folder` and writes a new file in it through a file coordinator, as a
        /// provider does, again until the presenter reports a change or the deadline passes: a
        /// presenter only hears of writes once the system has registered it, a little after it is
        /// added. Returns how many changes were reported, how many files were written, and
        /// whether the system still listed the presenter at the end.
        private func reported(
            in folder: URL, write: @escaping @Sendable (NSFileCoordinator, URL) throws -> Void
        ) async throws -> Report {
            let changes = Mutex(0)
            let presenter = FolderPresenter(folder: folder) { changes.withLock { $0 += 1 } }
            NSFileCoordinator.addFilePresenter(presenter)
            defer { NSFileCoordinator.removeFilePresenter(presenter) }
            let clock = ContinuousClock()
            let end = clock.now + Self.deadline
            var written = 0
            while clock.now < end, changes.withLock({ $0 }) == 0 {
                written += 1
                try write(NSFileCoordinator(), folder.appendingPathComponent("New \(written).txt"))
                try await Task.sleep(for: Self.pollInterval)
            }
            let isRegistered = NSFileCoordinator.filePresenters.contains { $0 === presenter }
            return Report(
                changes: changes.withLock { $0 }, written: written, isRegistered: isRegistered)
        }

        @Test func reportsAFileWrittenInTheFolder() async throws {
            let directory = try TempDirectory()
            let folder = try directory.makeFolder("Shown")

            let report = try await reported(in: folder) { coordinator, file in
                var failure: NSError?
                coordinator.coordinate(writingItemAt: file, options: [], error: &failure) { url in
                    try? Data("new".utf8).write(to: url)
                }
                if let failure { throw failure }
            }

            #expect(
                report.changes > 0,
                """
                \(report.written) files written in \(Self.deadline) were not heard; \
                the presenter was \(report.isRegistered ? "" : "not ")registered
                """)
        }
    }
}
