import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Stopping a copy while its coordinated read still waits, as it does while a cloud
/// provider downloads a file kept only online (ADR 0122).
@Suite struct CoordinatedStopTests {
    /// How long the presenter holds the reader at most, so that a copy that does not stop
    /// fails the test instead of hanging it. It counts from the reader's arrival, so a copy
    /// that waits its turn on the shared copy queue does not count against it.
    private static let deadline = DispatchTimeInterval.seconds(10)

    /// Presents a file and holds every reader off until it is released or its deadline
    /// passes, as a provider does until a download ends; `onReader` runs as a reader
    /// arrives, before it is held.
    private final class HoldingPresenter: NSObject, NSFilePresenter, Sendable {
        let presentedItemURL: URL?
        let presentedItemOperationQueue = OperationQueue()
        private let onReader: @Sendable () -> Void
        private let release = DispatchSemaphore(value: 0)
        private let released = Atomic(false)

        init(file: URL, onReader: @escaping @Sendable () -> Void) {
            presentedItemURL = file
            self.onReader = onReader
        }

        /// Whether the presenter has let the reader go.
        var hasReleased: Bool { released.load(ordering: .sequentiallyConsistent) }

        func letGo() { release.signal() }

        func relinquishPresentedItem(
            toReader reader: @escaping @Sendable ((@Sendable () -> Void)?) -> Void
        ) {
            onReader()
            _ = release.wait(timeout: .now() + CoordinatedStopTests.deadline)
            released.store(true, ordering: .sequentiallyConsistent)
            reader(nil)
        }
    }

    @Test func stopsACopyWhoseReadStillWaits() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        let file = try directory.makeFile("Online.jpg", contents: "photo")
        let control = TransferControl()
        // The user stops the copy while the provider still downloads the file.
        let presenter = HoldingPresenter(file: file, onReader: { control.stop() })
        NSFileCoordinator.addFilePresenter(presenter)
        defer { NSFileCoordinator.removeFilePresenter(presenter) }
        let runner = FileOperationRunner()
        let item = try await runner.item(at: FileItem.ID(file.path))

        let target = FileItem.ID(directory.url("to").path)

        let result = await Task {
            try await runner.copy(
                item, into: target, as: "Online.jpg", onFile: { _, _ in }, control: control)
        }.result
        let stoppedWhileHeld = !presenter.hasReleased
        presenter.letGo()

        #expect(stoppedWhileHeld, "the copy ended before the presenter let go")
        #expect(throws: FileSystemError.cancelled) { try result.get() }
        #expect(!FileManager.default.fileExists(atPath: directory.url("to/Online.jpg").path))
    }
}
