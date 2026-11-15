import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Which folders read quickly, so the sidebar may look inside them before they are opened
/// (ADR 0108).
@Suite struct LocalFileSystemQuickReadingTests {
    private func fileSystem(in directory: TempDirectory) -> LocalFileSystem {
        LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                mountedVolumes: { [] }))
    }

    private func id(_ directory: TempDirectory, _ path: String) -> FileItem.ID {
        FileItem.ID(directory.url(path).standardizedFileURL.path)
    }

    @Test func readsAFolderOnTheLocalDiskQuickly() throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home/Documents")
        #expect(fileSystem(in: directory).readsQuickly(id(directory, "home/Documents")))
    }

    @Test(arguments: ["home/Library/CloudStorage/Dropbox/Work", "home/Dropbox/Work"])
    func doesNotReadAFolderInTheCloudQuickly(_ path: String) throws {
        let directory = try TempDirectory()
        try directory.makeFolder(path)
        #expect(!fileSystem(in: directory).readsQuickly(id(directory, path)))
    }

    @Test func doesNotReadInsideAnArchiveQuickly() throws {
        let directory = try TempDirectory()
        let place = ArchivePath(archive: id(directory, "home/Photos.zip")).child("2024")
        #expect(!fileSystem(in: directory).readsQuickly(place.id))
    }

    @Test func doesNotReadThisMacQuickly() throws {
        let directory = try TempDirectory()
        #expect(!fileSystem(in: directory).readsQuickly(.computer))
    }
}
