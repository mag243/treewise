import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// Undoing and redoing operations through their records (ADR 0018).
@Suite struct UndoTests {
    let fileSystem = ChangingFileSystem()

    private func names(in folder: FileItem.ID) async throws -> [String] {
        try await fileSystem.contents(of: folder).map(\.name).sorted()
    }

    @Test func undoesAMove() async throws {
        let notes = try await fileSystem.item(at: "doc2")
        let moved = try await fileSystem.transfer(
            [notes], to: "projects", mode: .move, resolver: ScriptedResolver())
        try await fileSystem.undo(moved.undo)
        #expect(try await fileSystem.item(at: "doc2").parentID == "documents")
    }

    @Test func undoesACopyByTrashingTheCopies() async throws {
        let notes = try await fileSystem.item(at: "doc2")
        let copied = try await fileSystem.transfer(
            [notes], to: "projects", mode: .copy, resolver: ScriptedResolver())
        try await fileSystem.undo(copied.undo)
        #expect(!(try await names(in: "projects").contains("Notes.md")))
        #expect(fileSystem.trashedIDs.count == 1)
    }

    @Test func undoesAReplaceByRestoringTheReplacedItem() async throws {
        let notes = try await fileSystem.item(at: "doc2")
        try await fileSystem.transfer(
            [notes], to: "projects", mode: .copy, resolver: ScriptedResolver())
        let replaced = try await fileSystem.transfer(
            [notes], to: "projects", mode: .move, resolver: ScriptedResolver(.replace))
        try await fileSystem.undo(replaced.undo)
        #expect(try await names(in: "projects").contains("Notes.md"))
        #expect(try await names(in: "documents").contains("Notes.md"))
    }

    @Test func undoesAndRedoesARename() async throws {
        let notes = try await fileSystem.item(at: "doc2")
        let renamed = try await fileSystem.rename(notes, to: "Ideas.md")
        #expect(try await names(in: "documents").contains("Ideas.md"))
        let undone = try await fileSystem.undo(renamed.undo)
        #expect(try await names(in: "documents").contains("Notes.md"))
        try await fileSystem.undo(undone.undo)
        #expect(try await names(in: "documents").contains("Ideas.md"))
    }

    @Test func refusesARenameToATakenOrInvalidName() async throws {
        let notes = try await fileSystem.item(at: "doc2")
        await #expect(throws: FileSystemError.alreadyExists("doc2")) {
            try await fileSystem.rename(notes, to: "budget 2026.XLSX")
        }
        await #expect(throws: FileSystemError.invalidName("a/b")) {
            try await fileSystem.rename(notes, to: "a/b")
        }
    }

    @Test func allowsARenameThatOnlyChangesCase() async throws {
        let notes = try await fileSystem.item(at: "doc2")
        try await fileSystem.rename(notes, to: "notes.md")
        #expect(try await names(in: "documents").contains("notes.md"))
    }

    @Test func undoesANewFolderByTrashingIt() async throws {
        let created = try await fileSystem.createUntitledFolder(
            in: "documents", locale: Locale(identifier: "en"))
        #expect(try await names(in: "documents").contains("untitled folder"))
        try await fileSystem.undo(created.undo)
        #expect(!(try await names(in: "documents").contains("untitled folder")))
    }

    @Test func undoesMovingToTheTrash() async throws {
        let trashed = try await fileSystem.moveToTrash(["invoices"])
        #expect(!(try await names(in: "documents").contains("Invoices")))
        try await fileSystem.undo(trashed.undo)
        #expect(try await names(in: "invoices") == ["Invoice 2026-08.pdf", "Invoice 2026-09.pdf"])
    }
}
