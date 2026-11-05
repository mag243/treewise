import Synchronization
import Testing
import TreewiseCore
import TreewiseTestSupport

/// Moving and copying with name conflicts (PLAN.md §4.2, ADR 0018), on the
/// in-memory file system.
@Suite struct TransferTests {
    let fileSystem = ChangingFileSystem()

    private func names(in folder: FileItem.ID) async throws -> [String] {
        try await fileSystem.contents(of: folder).map(\.name).sorted()
    }

    private func item(_ id: FileItem.ID) async throws -> FileItem {
        try await fileSystem.item(at: id)
    }

    @Test func movesAFileIntoAnotherFolder() async throws {
        let result = try await fileSystem.transfer(
            [item("doc2")], to: "projects", mode: .move, resolver: ScriptedResolver())
        #expect(result.items.map(\.name) == ["Notes.md"])
        #expect(try await names(in: "projects").contains("Notes.md"))
        #expect(!(try await names(in: "documents").contains("Notes.md")))
    }

    @Test func copiesAFolderWithEverythingInside() async throws {
        let result = try await fileSystem.transfer(
            [item("invoices")], to: "backups", mode: .copy, resolver: ScriptedResolver())
        let copy = try #require(result.items.first)
        #expect(copy.volume == "usb")
        #expect(try await names(in: copy.id) == ["Invoice 2026-08.pdf", "Invoice 2026-09.pdf"])
        #expect(try await names(in: "invoices").count == 2)
    }

    @Test func keepsBothWithoutAskingWhenCopyingIntoTheSameFolder() async throws {
        let resolver = ScriptedResolver()
        try await fileSystem.transfer(
            [item("doc2")], to: "documents", mode: .copy, resolver: resolver)
        #expect(try await names(in: "documents").contains("Notes copy.md"))
        #expect(resolver.askedNames.isEmpty)
    }

    @Test func asksAndKeepsBothOnAConflict() async throws {
        try await fileSystem.transfer(
            [item("doc2")], to: "projects", mode: .copy, resolver: ScriptedResolver())
        let resolver = ScriptedResolver(.keepBoth)
        try await fileSystem.transfer(
            [item("doc2")], to: "projects", mode: .move, resolver: resolver)
        #expect(resolver.askedNames == ["Notes.md"])
        #expect(try await names(in: "projects").contains("Notes copy.md"))
    }

    @Test func replacesAnItemByMovingItToTheTrash() async throws {
        try await fileSystem.transfer(
            [item("doc2")], to: "projects", mode: .copy, resolver: ScriptedResolver())
        try await fileSystem.transfer(
            [item("doc2")], to: "projects", mode: .move, resolver: ScriptedResolver(.replace))
        #expect(try await names(in: "projects").filter { $0.hasPrefix("Notes") } == ["Notes.md"])
        #expect(fileSystem.trashedIDs.count == 1)
    }

    @Test func stopsAtAConflictAndKeepsWhatWasDone() async throws {
        try await fileSystem.transfer(
            [item("doc1")], to: "projects", mode: .copy, resolver: ScriptedResolver())
        let result = try await fileSystem.transfer(
            [item("doc2"), item("doc1"), item("doc3")], to: "projects", mode: .move,
            resolver: ScriptedResolver(.stop))
        #expect(result.stopped)
        #expect(result.items.map(\.name) == ["Notes.md"])
        #expect(!(try await names(in: "projects").contains("Lease agreement.pdf")))
    }

    @Test func skipsItemsThatAreAlreadyInTheTargetWhenMoving() async throws {
        let result = try await fileSystem.transfer(
            [item("doc2")], to: "documents", mode: .move, resolver: ScriptedResolver())
        #expect(result.items.isEmpty)
    }

    private func progress(
        of items: [FileItem.ID], to folder: FileItem.ID, mode: TransferMode
    ) async throws -> [OperationProgress] {
        let seen = Mutex<[OperationProgress]>([])
        try await fileSystem.transfer(
            items.asyncMap(item), to: folder, mode: mode, resolver: ScriptedResolver(),
            progress: { progress in seen.withLock { $0.append(progress) } })
        return seen.withLock { $0 }
    }

    /// Budget 2026.xlsx is 84,000 bytes and Notes.md 6,100 (`Fixture.standard`).
    @Test func reportsTheBytesCopiedBeforeEachFile() async throws {
        let seen = try await progress(of: ["doc1", "doc2"], to: "projects", mode: .copy)
        #expect(seen.first == OperationProgress(completedBytes: 0, totalBytes: 90_100))
        #expect(
            seen.contains(
                OperationProgress(
                    completedBytes: 84_000, totalBytes: 90_100, currentName: "Notes.md")))
        #expect(seen.last == OperationProgress(completedBytes: 90_100, totalBytes: 90_100))
    }

    /// A single large folder must show its progress while it copies, not only once it is done.
    @Test func namesEachFileOfACopiedFolder() async throws {
        let seen = try await progress(of: ["src"], to: "documents", mode: .copy)
        #expect(
            Set(seen.compactMap(\.currentName))
                == ["TreewiseApp.swift", "FileTreeView.swift", "DetailsListView.swift"])
        #expect(seen.last?.completedBytes == 16_500)
    }

    @Test func countsNoBytesForAMoveWithinTheVolume() async throws {
        let seen = try await progress(of: ["doc2"], to: "projects", mode: .move)
        #expect(seen.allSatisfy { $0.totalBytes == 0 })
    }
}

extension Array {
    fileprivate func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        for element in self { result.append(try await transform(element)) }
        return result
    }
}
