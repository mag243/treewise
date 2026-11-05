import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// How one item on disk maps onto `FileItem` (ADR 0016).
@Suite struct LocalFileSystemItemTests {
    private func item(_ relativePath: String, in directory: TempDirectory) async throws -> FileItem
    {
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))
        return try await fileSystem.item(at: FileItem.ID(directory.path + "/" + relativePath))
    }

    @Test func readsAFilesNameSizeKindAndDate() async throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile("Notes.md", contents: "hello")
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)

        let notes = try await item("Notes.md", in: directory)

        #expect(notes.name == "Notes.md")
        #expect(notes.kind == .file)
        #expect(notes.size == 5)
        #expect(notes.modified == date)
        #expect(notes.kindDescription?.isEmpty == false)
    }

    @Test func givesAFolderNoSize() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Projects")
        let projects = try await item("Projects", in: directory)
        #expect(projects.kind == .folder)
        #expect(projects.size == nil)
    }

    @Test func countsAPackageAsOneItemWithoutSize() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Tool.app/Contents")
        let tool = try await item("Tool.app", in: directory)
        #expect(tool.kind == .package)
        #expect(tool.size == nil)
    }

    @Test func showsASymlinkAsAFileWithoutFollowingIt() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Projects")
        try directory.makeSymlink("Shortcut", to: "Projects")
        let shortcut = try await item("Shortcut", in: directory)
        #expect(shortcut.kind == .file)
        #expect(shortcut.id == FileItem.ID(directory.path + "/Shortcut"))
    }

    @Test func putsTheItemOnTheVolumeOfItsFolder() async throws {
        let directory = try TempDirectory()
        try directory.makeFile("Notes.md")
        let notes = try await item("Notes.md", in: directory)
        let volume = try directory.url.resourceValues(forKeys: [.volumeURLKey]).volume
        #expect(notes.volume == VolumeID(try #require(volume).path))
    }

    @Test func throwsNotFoundForAMissingItem() async throws {
        let directory = try TempDirectory()
        await #expect(throws: FileSystemError.notFound(FileItem.ID(directory.path + "/missing"))) {
            try await item("missing", in: directory)
        }
    }

    @Test func derivesAncestryFromThePathAlone() {
        #expect(LocalFileSystem.ancestry("/a/b/c") == ["/a/b", "/a", "/"])
        #expect(LocalFileSystem.ancestry("/") == [])
    }

    @Test func readsAnItemSynchronouslyForADragInProgress() async throws {
        let directory = try TempDirectory()
        try directory.makeFile("Notes.md", contents: "hello")
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))
        let id = FileItem.ID(directory.path + "/Notes.md")
        #expect(try fileSystem.currentItem(at: id) == (try await fileSystem.item(at: id)))
    }

    @Test func reportsAMissingItemSynchronously() throws {
        let directory = try TempDirectory()
        let id = FileItem.ID(directory.path + "/Gone.md")
        #expect(throws: FileSystemError.notFound(id)) { try LocalFileSystem().currentItem(at: id) }
    }
}
