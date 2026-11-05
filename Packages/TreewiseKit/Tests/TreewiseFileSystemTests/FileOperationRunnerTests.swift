import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Changing files on disk (PLAN.md §9.3, ADR 0018), always inside a TempDirectory.
@Suite struct FileOperationRunnerTests {
    private func runner(_ directory: TempDirectory) -> FileOperationRunner {
        FileOperationRunner(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))
    }

    private func id(_ directory: TempDirectory, _ relativePath: String) -> FileItem.ID {
        FileItem.ID(directory.path + "/" + relativePath)
    }

    private func names(_ directory: TempDirectory, in folder: String, hidden: Bool = true) throws
        -> [String]
    {
        try FileManager.default.contentsOfDirectory(atPath: directory.url(folder).path)
            .filter { hidden || !$0.hasPrefix(".") }.sorted()
    }

    @Test func copiesAFileWithItsContents() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("from")
        try directory.makeFolder("to")
        try directory.makeFile("from/Notes.md", contents: "hello")
        let runner = runner(directory)

        let notes = try await runner.item(at: id(directory, "from/Notes.md"))
        let result = try await runner.transfer(
            [notes], to: id(directory, "to"), mode: .copy, resolver: ScriptedResolver())

        #expect(result.items.map(\.id) == [id(directory, "to/Notes.md")])
        #expect(try String(contentsOf: directory.url("to/Notes.md"), encoding: .utf8) == "hello")
        #expect(FileManager.default.fileExists(atPath: directory.url("from/Notes.md").path))
    }

    @Test func copiesANestedFolderKeepingSymlinksAsSymlinks() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("from/Project/Sources")
        try directory.makeFile("from/Project/Sources/main.swift", contents: "x")
        try directory.makeSymlink("from/Project/Link", to: "from/Project/Sources")
        try directory.makeFolder("to")
        let runner = runner(directory)

        let project = try await runner.item(at: id(directory, "from/Project"))
        try await runner.transfer(
            [project], to: id(directory, "to"), mode: .copy, resolver: ScriptedResolver())

        #expect(try names(directory, in: "to/Project") == ["Link", "Sources"])
        let link = try directory.url("to/Project/Link").resourceValues(forKeys: [.isSymbolicLinkKey]
        )
        #expect(link.isSymbolicLink == true)
        #expect(
            FileManager.default.fileExists(
                atPath: directory.url("to/Project/Sources/main.swift").path))
    }

    @Test func movesAFileWithinItsVolume() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        try directory.makeFile("Notes.md", contents: "x")
        let runner = runner(directory)

        let notes = try await runner.item(at: id(directory, "Notes.md"))
        try await runner.transfer(
            [notes], to: id(directory, "to"), mode: .move, resolver: ScriptedResolver())

        #expect(try names(directory, in: "to") == ["Notes.md"])
        #expect(!FileManager.default.fileExists(atPath: directory.url("Notes.md").path))
    }

    @Test func keepsBothOnAConflictOnDisk() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        try directory.makeFile("Notes.md", contents: "new")
        try directory.makeFile("to/Notes.md", contents: "old")
        let runner = runner(directory)

        let notes = try await runner.item(at: id(directory, "Notes.md"))
        try await runner.transfer(
            [notes], to: id(directory, "to"), mode: .copy, resolver: ScriptedResolver(.keepBoth))

        #expect(try names(directory, in: "to") == ["Notes copy.md", "Notes.md"])
        #expect(try String(contentsOf: directory.url("to/Notes.md"), encoding: .utf8) == "old")
    }

    @Test func renamesAndUndoesTheRename() async throws {
        let directory = try TempDirectory()
        try directory.makeFile("notes.md")
        let runner = runner(directory)

        let notes = try await runner.item(at: id(directory, "notes.md"))
        let renamed = try await runner.rename(notes, to: "Notes.md")
        #expect(try names(directory, in: "") == ["Notes.md"])

        try await runner.undo(renamed.undo)
        #expect(try names(directory, in: "") == ["notes.md"])
    }

    @Test func undoesAMoveOnDisk() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        try directory.makeFile("Notes.md")
        let runner = runner(directory)

        let notes = try await runner.item(at: id(directory, "Notes.md"))
        let moved = try await runner.transfer(
            [notes], to: id(directory, "to"), mode: .move, resolver: ScriptedResolver())
        try await runner.undo(moved.undo)

        #expect(try names(directory, in: "") == ["Notes.md", "to"])
    }

    @Test func createsAnUntitledFolder() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("untitled folder")
        let created = try await runner(directory).createUntitledFolder(
            in: FileItem.ID(directory.path), locale: Locale(identifier: "en"))
        #expect(created.items.map(\.name) == ["untitled folder 2"])
        #expect(created.items.first?.kind == .folder)
    }

    @Test func countsTheBytesOfAFolder() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Clips")
        try directory.makeFile("Clips/a.mov", contents: "12345")
        try directory.makeFile("Clips/b.mov", contents: "123")
        let runner = runner(directory)
        let clips = try await runner.item(at: id(directory, "Clips"))
        #expect(try await runner.byteCount(of: clips) == 8)
    }

    @Test func reportsEachFileOfAFolderBeforeCopyingIt() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Clips")
        try directory.makeFile("Clips/a.mov", contents: "12345")
        try directory.makeFile("Clips/b.mov", contents: "123")
        try directory.makeFolder("to")
        let runner = runner(directory)
        let clips = try await runner.item(at: id(directory, "Clips"))
        let seen = Mutex<[String: Int64]>([:])

        _ = try await runner.copy(
            clips, into: id(directory, "to"), as: "Clips",
            onFile: { file, copied in seen.withLock { $0[file] = copied } },
            control: TransferControl())

        let reports = seen.withLock { $0 }
        #expect(Set(reports.keys) == ["a.mov", "b.mov"])
        #expect(Set(reports.values) == [0, reports["a.mov"] == 0 ? 5 : 3])
    }

    @Test func leavesNoPartialCopyWhenCancelled() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        for index in 1...5 { try directory.makeFile("file \(index).txt", contents: "x") }
        let runner = runner(directory)
        var items: [FileItem] = []
        for index in 1...5 {
            items.append(try await runner.item(at: id(directory, "file \(index).txt")))
        }

        let selection = items
        let target = id(directory, "to")
        let task = Task {
            try await runner.transfer(
                selection, to: target, mode: .copy, resolver: ScriptedResolver(),
                progress: { progress in
                    // Once the first file is done and before the next one starts.
                    guard progress.completedBytes > 0, progress.currentName == nil else { return }
                    withUnsafeCurrentTask { $0?.cancel() }
                })
        }
        let result = try await task.value

        #expect(result.stopped)
        #expect(try names(directory, in: "to") == ["file 1.txt"])
    }

    @Test func leavesNoPartialCopyWhenACopyFails() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("to")
        let locked = try directory.makeFile("Locked.txt", contents: "secret")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644], ofItemAtPath: locked.path)
        }
        let runner = runner(directory)

        let item = try await runner.item(at: id(directory, "Locked.txt"))
        await #expect(throws: (any Error).self) {
            try await runner.transfer(
                [item], to: id(directory, "to"), mode: .copy, resolver: ScriptedResolver())
        }
        #expect(try names(directory, in: "to").isEmpty)
    }
}
