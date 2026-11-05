import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// The runner coordinates every access (ADR 0047), so iCloud Drive and File
/// Provider apps, which present their files, hear of each read and change.
@Suite struct FileCoordinationTests {
    /// How long a presenter may take to hear of an access.
    private static let deadline = Duration.seconds(2)

    private func runner(_ directory: TempDirectory) -> FileOperationRunner {
        FileOperationRunner(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))
    }

    @Test func aCopyReadsTheSourceCoordinated() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        let source = try directory.makeFile("Notes.md", contents: "hello")
        let presenter = Presenter(source)
        defer { presenter.stop() }
        let runner = runner(directory)

        let notes = try await runner.item(at: FileItem.ID(source.path))
        _ = try await runner.transfer(
            [notes], to: FileItem.ID(directory.url("to").path), mode: .copy,
            resolver: ScriptedResolver())

        #expect(await presenter.hears("read", within: Self.deadline))
    }

    @Test func aMoveWritesTheSourceCoordinated() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        let source = try directory.makeFile("Notes.md")
        let presenter = Presenter(source)
        defer { presenter.stop() }
        let runner = runner(directory)

        let notes = try await runner.item(at: FileItem.ID(source.path))
        _ = try await runner.transfer(
            [notes], to: FileItem.ID(directory.url("to").path), mode: .move,
            resolver: ScriptedResolver())

        #expect(await presenter.hears("write", within: Self.deadline))
    }

    @Test func aRenameWritesTheItemCoordinated() async throws {
        let directory = try TempDirectory()
        let source = try directory.makeFile("Notes.md")
        let presenter = Presenter(source)
        defer { presenter.stop() }
        let runner = runner(directory)

        let notes = try await runner.item(at: FileItem.ID(source.path))
        _ = try await runner.rename(notes, to: "Ideas.md")

        #expect(await presenter.hears("write", within: Self.deadline))
    }

    @Test(.enabled(if: TrashAvailability.inTemporaryDirectory, "needs a Trash"))
    func movingToTheTrashDeletesCoordinated() async throws {
        let directory = try TempDirectory()
        let source = try directory.makeFile("Notes.md")
        let presenter = Presenter(source)
        defer { presenter.stop() }
        let runner = runner(directory)

        let trashed = try await runner.trash(FileItem.ID(source.path))
        defer { try? TrashService().restore(trashed) }

        #expect(await presenter.hears("delete", within: Self.deadline))
    }

    @Test func aNewFolderIsWrittenCoordinated() async throws {
        let directory = try TempDirectory()
        let parent = try directory.makeFolder("Projects")
        let presenter = Presenter(parent.appendingPathComponent("New"))
        defer { presenter.stop() }

        _ = try await runner(directory).createFolder(
            in: FileItem.ID(parent.path), named: "New")

        #expect(await presenter.hears("write", within: Self.deadline))
    }
}

/// Presents one file or folder, which may not exist yet, and records what other coordinators ask of it.
private final class Presenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let events: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init(_ url: URL) {
        presentedItemURL = url
        (events, continuation) = AsyncStream.makeStream()
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    func stop() {
        NSFileCoordinator.removeFilePresenter(self)
    }

    /// Whether `event` arrives before `deadline`.
    func hears(_ event: String, within deadline: Duration) async -> Bool {
        let events = events
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await heard in events where heard == event { return true }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: deadline)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    // Only a coordinated access asks a presenter to let go of its item first;
    // an uncoordinated one changes the item without asking.

    func relinquishPresentedItem(
        toReader reader: @escaping @Sendable ((@Sendable () -> Void)?) -> Void
    ) {
        continuation.yield("read")
        reader(nil)
    }

    func relinquishPresentedItem(
        toWriter writer: @escaping @Sendable ((@Sendable () -> Void)?) -> Void
    ) {
        continuation.yield("write")
        writer(nil)
    }

    func accommodatePresentedItemDeletion(
        completionHandler: @escaping @Sendable (Error?) -> Void
    ) {
        continuation.yield("delete")
        completionHandler(nil)
    }
}
