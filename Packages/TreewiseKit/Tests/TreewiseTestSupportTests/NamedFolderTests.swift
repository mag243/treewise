import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// A new folder made with the name the user typed first, as the iPad asks it (ADR 0130).
@Suite struct NamedFolderTests {
    let fileSystem = ChangingFileSystem()

    private func names(in folder: FileItem.ID) async throws -> [String] {
        try await fileSystem.contents(of: folder).map(\.name)
    }

    @Test func makesAFolderWithTheNameGivenAndUndoesIt() async throws {
        let created = try await fileSystem.createFolder(named: "Receipts", in: "documents")
        #expect(created.items.map(\.name) == ["Receipts"])
        try await fileSystem.undo(created.undo)
        #expect(!(try await names(in: "documents").contains("Receipts")))
    }

    @Test func refusesANameAnotherItemHas() async throws {
        await #expect(throws: FileSystemError.self) {
            try await fileSystem.createFolder(named: "notes.md", in: "documents")
        }
        #expect(
            try await names(in: "documents").filter { $0.lowercased() == "notes.md" }.count == 1)
    }

    @Test func refusesANameThatCannotBeUsed() async throws {
        await #expect(throws: FileSystemError.invalidName("a/b")) {
            try await fileSystem.createFolder(named: "a/b", in: "documents")
        }
    }
}
