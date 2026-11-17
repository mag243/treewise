import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Deleting permanently, which the user confirms where a location has no Trash (ADR 0128),
/// always inside a TempDirectory.
@Suite struct PermanentDeleteTests {
    @Test func deletesAFolderWithItsContents() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Old/Inside")
        try directory.makeFile("Old/Inside/Notes.md")

        try await directory.runner.deletePermanently(FileItem.ID(directory.url("Old").path))

        #expect(!FileManager.default.fileExists(atPath: directory.url("Old").path))
    }

    @Test func refusesAnItemOutsideTheBoundary() async throws {
        let directory = try TempDirectory()
        let outside = try TempDirectory()
        let file = try outside.makeFile("Keep.md")

        let runner = FileOperationRunner(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                boundary: [directory.url]))

        await #expect(throws: (any Error).self) {
            try await runner.deletePermanently(FileItem.ID(file.path))
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
