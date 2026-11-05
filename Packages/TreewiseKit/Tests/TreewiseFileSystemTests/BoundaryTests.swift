import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// A boundary keeps the app on the sandbox volumes or a test folder (ADR 0019):
/// nothing outside it is read or changed.
@Suite struct BoundaryTests {
    /// A temporary directory with `inside/` as the boundary and `outside/` next to it.
    private struct Setup {
        let directory: TempDirectory
        let locations: LocalFileSystem.Locations

        init() throws {
            directory = try TempDirectory()
            try directory.makeFolder("inside/Documents")
            try directory.makeFile("inside/Notes.md", contents: "inside")
            try directory.makeFolder("outside")
            try directory.makeFile("outside/Secret.md", contents: "outside")
            locations = .init(
                home: directory.url("inside"), applications: directory.url("inside/Applications"),
                mountedVolumes: { [] }, boundary: [directory.url("inside")])
        }

        func id(_ relativePath: String) -> FileItem.ID {
            FileItem.ID(directory.path + "/" + relativePath)
        }
    }

    @Test func readsItemsInsideTheBoundary() async throws {
        let setup = try Setup()
        let notes = try await LocalFileSystem(locations: setup.locations).item(
            at: setup.id("inside/Notes.md"))
        #expect(notes.parentID == setup.id("inside"))
    }

    @Test func refusesToReadAnItemOutsideTheBoundary() async throws {
        let setup = try Setup()
        let secret = setup.id("outside/Secret.md")
        await #expect(throws: FileSystemError.outsideBoundary(secret)) {
            try await LocalFileSystem(locations: setup.locations).item(at: secret)
        }
    }

    @Test func refusesToListAFolderOutsideTheBoundary() async throws {
        let setup = try Setup()
        await #expect(throws: FileSystemError.outsideBoundary(setup.id("outside"))) {
            try await LocalFileSystem(locations: setup.locations).contents(of: setup.id("outside"))
        }
    }

    @Test func doesNotTakeAFolderThatOnlySharesThePrefix() async throws {
        let setup = try Setup()
        try setup.directory.makeFolder("inside-not")
        await #expect(throws: FileSystemError.outsideBoundary(setup.id("inside-not"))) {
            try await LocalFileSystem(locations: setup.locations).item(at: setup.id("inside-not"))
        }
    }

    @Test func givesABoundaryRootNoEnclosingFolder() async throws {
        let setup = try Setup()
        let fileSystem = LocalFileSystem(locations: setup.locations)
        #expect(try await fileSystem.item(at: setup.id("inside")).parentID == nil)
        #expect(
            try await fileSystem.ancestorIDs(of: setup.id("inside/Documents")) == [
                setup.id("inside")
            ])
    }

    @Test func refusesToCopyIntoAFolderOutsideTheBoundary() async throws {
        let setup = try Setup()
        let runner = FileOperationRunner(locations: setup.locations)
        let notes = try await runner.item(at: setup.id("inside/Notes.md"))
        await #expect(throws: FileSystemError.outsideBoundary(setup.id("outside"))) {
            try await runner.transfer(
                [notes], to: setup.id("outside"), mode: .copy, resolver: ScriptedResolver())
        }
        #expect(
            !FileManager.default.fileExists(atPath: setup.directory.url("outside/Notes.md").path))
    }

    @Test func refusesToMoveAnItemFromOutsideTheBoundaryIn() async throws {
        let setup = try Setup()
        let secret = try await LocalFileSystem().item(at: setup.id("outside/Secret.md"))
        let runner = FileOperationRunner(locations: setup.locations)
        await #expect(throws: FileSystemError.outsideBoundary(secret.id)) {
            try await runner.transfer(
                [secret], to: setup.id("inside/Documents"), mode: .move,
                resolver: ScriptedResolver())
        }
        #expect(
            FileManager.default.fileExists(atPath: setup.directory.url("outside/Secret.md").path))
    }

    @Test func refusesToTrashAnItemOutsideTheBoundary() async throws {
        let setup = try Setup()
        let secret = setup.id("outside/Secret.md")
        await #expect(throws: FileSystemError.outsideBoundary(secret)) {
            try await FileOperationRunner(locations: setup.locations).moveToTrash([secret])
        }
        #expect(
            FileManager.default.fileExists(atPath: setup.directory.url("outside/Secret.md").path))
    }

    @Test func refusesToCreateAFolderOutsideTheBoundary() async throws {
        let setup = try Setup()
        await #expect(throws: FileSystemError.outsideBoundary(setup.id("outside"))) {
            try await FileOperationRunner(locations: setup.locations).createFolder(
                in: setup.id("outside"), named: "New")
        }
    }
}
