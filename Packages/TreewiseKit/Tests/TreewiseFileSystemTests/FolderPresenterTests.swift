import Foundation
import Synchronization
import Testing
import TreewiseFileSystem
import TreewiseTestSupport

/// A folder's changes as the system reports them to a file presenter, which is how a
/// cloud provider's changes reach other apps on the iPad (ADR 0120).
@Suite struct FolderPresenterTests {
    /// How long a change may take to arrive.
    private static let deadline = Duration.seconds(2)
    /// How often the count is looked at while waiting.
    private static let pollInterval = Duration.milliseconds(20)

    /// Presents `folder`, writes through a file coordinator as a provider does, and
    /// returns how many changes were reported in time.
    private func reported(
        in folder: URL, write: @escaping @Sendable (NSFileCoordinator) throws -> Void
    ) async throws -> Int {
        let changes = Mutex(0)
        let presenter = FolderPresenter(folder: folder) { changes.withLock { $0 += 1 } }
        NSFileCoordinator.addFilePresenter(presenter)
        defer { NSFileCoordinator.removeFilePresenter(presenter) }
        try write(NSFileCoordinator())
        let clock = ContinuousClock()
        let end = clock.now + Self.deadline
        while clock.now < end, changes.withLock({ $0 }) == 0 {
            try await Task.sleep(for: Self.pollInterval)
        }
        return changes.withLock { $0 }
    }

    @Test func reportsAFileWrittenInTheFolder() async throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("Shown")
        let file = folder.appendingPathComponent("New.txt")

        let changes = try await reported(in: folder) { coordinator in
            var failure: NSError?
            coordinator.coordinate(writingItemAt: file, options: [], error: &failure) { url in
                try? Data("new".utf8).write(to: url)
            }
            if let failure { throw failure }
        }

        #expect(changes > 0)
    }
}
