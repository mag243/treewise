import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Moving to the Trash and back (PLAN.md §9.3). The one exception to "only in
/// a TempDirectory": these tests use the real Trash, and each takes back what
/// it put there (ADR 0018). Where there is no Trash, as in the iOS
/// Simulator's test process, only the tests that need none run (ADR 0047).
@Suite struct TrashServiceTests {
    private let service = TrashService()

    @Test(.enabled(if: TrashAvailability.inTemporaryDirectory, "needs a Trash"))
    func movesAnItemToTheTrash() throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile(
            "Treewise trash test \(UUID().uuidString).txt", contents: "x")
        let trashed = try service.trash(FileItem.ID(file.path))
        defer { try? service.restore(trashed) }

        #expect(FileManager.default.fileExists(atPath: trashed.trashID.rawValue))
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(trashed.originalID == FileItem.ID(file.path))
    }

    @Test(.enabled(if: TrashAvailability.inTemporaryDirectory, "needs a Trash"))
    func putsAnItemBackFromTheTrash() throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile(
            "Treewise trash test \(UUID().uuidString).txt", contents: "x")
        let trashed = try service.trash(FileItem.ID(file.path))
        try service.restore(trashed)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(!FileManager.default.fileExists(atPath: trashed.trashID.rawValue))
    }

    @Test(.disabled(if: TrashAvailability.inTemporaryDirectory, "needs a place without a Trash"))
    func reportsAPlaceWithoutATrash() throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile("Notes.md")
        #expect(throws: FileSystemError.trashUnavailable(FileItem.ID(file.path))) {
            try service.trash(FileItem.ID(file.path))
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func throwsNotFoundForAMissingItem() throws {
        let directory = try TempDirectory()
        let missing = FileItem.ID(directory.path + "/missing")
        #expect(throws: FileSystemError.notFound(missing)) {
            try service.trash(missing)
        }
    }
}
