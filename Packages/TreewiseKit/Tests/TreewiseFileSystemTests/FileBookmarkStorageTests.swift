import Foundation
import Testing
import TreewiseFileSystem
import TreewiseTestSupport

/// Bookmarks kept in a file of the app's own (ADR 0045).
@Suite struct FileBookmarkStorageTests {
    /// A file that is there but cannot be read, as without permission, is never written
    /// over as if it held no bookmarks: every location in it would be lost.
    @Test func leavesAFileItCannotReadAsItIs() throws {
        let root = try TempDirectory()
        let file = root.url("bookmarks.json")
        let kept = Data("[]".utf8) + Data(" ".utf8)
        try kept.write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o200], ofItemAtPath: file.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
        let storage = FileBookmarkStorage(file: file)
        storage.save(storage.load())
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        #expect(try Data(contentsOf: file) == kept)
    }

    @Test func savesWhenThereIsNoFileYet() throws {
        let root = try TempDirectory()
        let storage = FileBookmarkStorage(file: root.url("bookmarks.json"))
        storage.save([])
        #expect(FileManager.default.fileExists(atPath: root.url("bookmarks.json").path))
    }
}
