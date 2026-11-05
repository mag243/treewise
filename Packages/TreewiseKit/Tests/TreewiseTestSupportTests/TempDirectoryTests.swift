import Foundation
import Testing
import TreewiseTestSupport

@Suite struct TempDirectoryTests {
    @Test func createsAnEmptyFolderUnderTheTemporaryDirectory() throws {
        let directory = try TempDirectory()
        let temporary = FileManager.default.temporaryDirectory.path
        #expect(directory.path.hasPrefix(temporary))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func removesTheFolderWithItsContentsWhenReleased() throws {
        var directory: TempDirectory? = try TempDirectory()
        let path = try #require(directory).path
        try directory?.makeFolder("a/b")
        try directory?.makeFile("a/b/note.txt", contents: "x")
        directory = nil
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func createsFilesFoldersAndLinks() throws {
        let directory = try TempDirectory()
        try directory.makeFolder("folder")
        try directory.makeFile("folder/note.txt", contents: "hello")
        try directory.makeSymlink("link", to: "folder")
        let contents = try String(contentsOf: directory.url("folder/note.txt"), encoding: .utf8)
        #expect(contents == "hello")
        let destination = try FileManager.default.destinationOfSymbolicLink(
            atPath: directory.url("link").path)
        #expect(destination == directory.url("folder").path)
    }
}
