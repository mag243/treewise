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

    @Test func removesAReadOnlyTree() throws {
        var directory: TempDirectory? = try TempDirectory()
        let path = try #require(directory).path
        try directory?.makeFolder("locked/inside")
        try directory?.makeFile("locked/inside/note.txt", contents: "x")
        for folder in ["locked/inside", "locked"] {
            try FileManager.default.setAttributes(
                [.posixPermissions: Self.readOnly], ofItemAtPath: path + "/" + folder)
        }
        directory = nil
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func leavesAFolderBehindALinkAsItIs() throws {
        let elsewhere = try TempDirectory()
        let kept = try elsewhere.makeFolder("kept")
        try FileManager.default.setAttributes(
            [.posixPermissions: Self.readOnly], ofItemAtPath: kept.path)
        var directory: TempDirectory? = try TempDirectory()
        try FileManager.default.createSymbolicLink(
            at: try #require(directory).url("link"), withDestinationURL: kept)
        directory = nil
        let mode = try FileManager.default.attributesOfItem(atPath: kept.path)[.posixPermissions]
        #expect(mode as? Int == Self.readOnly)
    }

    /// Read and search for everyone, writing for no one, as a folder from a disk image.
    private static let readOnly = 0o555
}
