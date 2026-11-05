import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// External changes reach the list within a second (PLAN.md §9.3, ADR 0016).
@Suite struct DirectoryWatcherTests {
    /// How long a change may take to arrive.
    private static let deadline = Duration.seconds(1)

    /// Starts watching `directory`, runs `change`, and reports whether a change
    /// event arrived before the deadline.
    private func reportsChange(
        in directory: TempDirectory, after change: () throws -> Void
    ) async throws -> Bool {
        let events = DirectoryWatcher().changes(of: FileItem.ID(directory.path))
        try change()
        return await Self.firstEvent(of: events)
    }

    private static func firstEvent(of events: AsyncStream<Void>) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = events.makeAsyncIterator()
                return await iterator.next() != nil
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

    /// Whether a change arrives when the watcher follows file changes. FSEvents
    /// can still deliver what happened just before the stream started, so the
    /// count settles first and only what arrives after `change` counts.
    private func reportsFileChange(
        in directory: TempDirectory, after change: () throws -> Void
    ) async throws -> Bool {
        let events = DirectoryWatcher(watchesFileChanges: { _ in true }).changes(
            of: FileItem.ID(directory.path))
        let count = Mutex(0)
        let counting = Task {
            for await _ in events { count.withLock { $0 += 1 } }
        }
        defer { counting.cancel() }
        var settled = -1
        while settled != count.withLock({ $0 }) {
            settled = count.withLock { $0 }
            try await Task.sleep(for: Self.deadline / 2)
        }
        try change()
        try await Task.sleep(for: Self.deadline)
        return count.withLock { $0 } > settled
    }

    @Test func reportsAFileChangingInAFolderFollowedForFiles() async throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile("report.pdf")
        #expect(
            try await reportsFileChange(in: directory) {
                try Data("changed".utf8).write(to: file)
            })
    }

    @Test func doesNotReportAFileChangingInASubfolder() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Work")
        let file = try directory.makeFile("Work/report.pdf")
        #expect(
            try await !reportsFileChange(in: directory) {
                try Data("changed".utf8).write(to: file)
            })
    }

    @Test func reportsACreatedFile() async throws {
        let directory = try TempDirectory()
        #expect(try await reportsChange(in: directory) { try directory.makeFile("new.txt") })
    }

    @Test func reportsARenamedFile() async throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile("old.txt")
        #expect(
            try await reportsChange(in: directory) {
                try FileManager.default.moveItem(at: file, to: directory.url("new.txt"))
            })
    }

    @Test func reportsADeletedFile() async throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile("gone.txt")
        #expect(
            try await reportsChange(in: directory) { try FileManager.default.removeItem(at: file) })
    }

    @Test func finishesAtOnceForAMissingFolder() async throws {
        let directory = try TempDirectory()
        let events = DirectoryWatcher().changes(of: FileItem.ID(directory.path + "/missing"))
        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }

    @Test func reportsTheMountTableForThisMac() async {
        let (changes, continuation) = AsyncStream<Void>.makeStream()
        let events = DirectoryWatcher(mountTableChanges: { changes }).changes(of: .computer)
        continuation.yield()
        #expect(await Self.firstEvent(of: events), "a volume mounted or ejected")
    }
}
