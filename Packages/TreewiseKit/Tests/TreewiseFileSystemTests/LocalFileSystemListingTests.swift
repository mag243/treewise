import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Reading a folder's items with no more values than each needs (ADR 0126).
@Suite struct LocalFileSystemListingTests {
    @Test func listsAPackageAsAPackageAndAFileAsAFile() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Folder/Tool.app/Contents")
        try directory.makeFolder("Folder/Projects")
        try directory.makeFile("Folder/Notes.md")

        let items = try await LocalFileSystem().contents(
            of: FileItem.ID(directory.url("Folder").path))

        let kinds = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.kind) })
        #expect(kinds == ["Tool.app": .package, "Projects": .folder, "Notes.md": .file])
    }

    @Test func aFileOnDiskIsNotDataless() throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile("Here.jpg", contents: "photo")

        #expect(!LocalFileSystem.Locations.systemIsDataless(file))
    }
}
