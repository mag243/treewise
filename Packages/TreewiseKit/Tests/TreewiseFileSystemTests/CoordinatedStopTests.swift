import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Stopping a copy while its coordinated read still waits, as it does while a cloud
/// provider downloads a file kept only online (ADR 0122).
@Suite struct CoordinatedStopTests {
    /// How long the presenter waits for the reader and then holds it at most, so that a
    /// copy that does not stop fails the test instead of hanging it. Generous, as the copy
    /// queue is shared with the other tests' copies.
    private static let deadline = DispatchTimeInterval.seconds(10)

    /// Presents a file and holds every reader off until it is released or its deadline
    /// passes, as a provider does until a download ends.
    private final class HoldingPresenter: NSObject, NSFilePresenter, Sendable {
        let presentedItemURL: URL?
        let presentedItemOperationQueue = OperationQueue()
        /// Signalled once a reader asks for the file.
        private let asked = DispatchSemaphore(value: 0)
        private let release = DispatchSemaphore(value: 0)
        private let released = Atomic(false)

        init(file: URL) {
            presentedItemURL = file
        }

        /// Whether the presenter has let the reader go.
        var hasReleased: Bool { released.load(ordering: .sequentiallyConsistent) }

        func letGo() { release.signal() }

        /// Blocks until a reader asks for the file; false when none does in time.
        func waitForReader() -> Bool {
            asked.wait(timeout: .now() + CoordinatedStopTests.deadline) == .success
        }

        func relinquishPresentedItem(
            toReader reader: @escaping @Sendable ((@Sendable () -> Void)?) -> Void
        ) {
            asked.signal()
            _ = release.wait(timeout: .now() + CoordinatedStopTests.deadline)
            released.store(true, ordering: .sequentiallyConsistent)
            reader(nil)
        }
    }

    @Test func stopsACopyWhoseReadStillWaits() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        let file = try directory.makeFile("Online.jpg", contents: "photo")
        let presenter = HoldingPresenter(file: file)
        NSFileCoordinator.addFilePresenter(presenter)
        defer { NSFileCoordinator.removeFilePresenter(presenter) }
        let runner = FileOperationRunner()
        let item = try await runner.item(at: FileItem.ID(file.path))
        let control = TransferControl()

        let target = FileItem.ID(directory.url("to").path)

        let copying = Task {
            try await runner.copy(
                item, into: target, as: "Online.jpg", onFile: { _, _ in }, control: control)
        }
        #expect(await Task.detached { presenter.waitForReader() }.value)
        control.stop()
        let result = await copying.result
        let stoppedWhileHeld = !presenter.hasReleased
        presenter.letGo()

        #expect(stoppedWhileHeld, "the copy ended before the presenter let go")
        #expect(throws: FileSystemError.cancelled) { try result.get() }
        #expect(!FileManager.default.fileExists(atPath: directory.url("to/Online.jpg").path))
    }
}
