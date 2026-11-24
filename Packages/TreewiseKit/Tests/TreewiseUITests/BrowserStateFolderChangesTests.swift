import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// What Treewise does names the folders whose entries it changed, so every window's sidebar
/// reads their rows again, also of a folder no pane shows (ADR 0112).
@MainActor
@Suite struct BrowserStateFolderChangesTests {
    let fileSystem = ChangingFileSystem()

    private func browser() async -> BrowserState {
        await makeBrowser(fileSystem: fileSystem, at: "documents")
    }

    @Test func foldersMadeFromATemplateNameTheFolderTheyWereMadeIn() async {
        let browser = await browser()
        var changes = browser.folderChanges.changes().makeAsyncIterator()

        await browser.createFolders(
            making: FolderTree(name: "2028", folders: [FolderTree(name: "Tax")]),
            in: "projects", undoManager: nil)

        #expect(await changes.next() == ["projects"])
    }

    @Test func aMoveNamesTheFolderItLeftAndTheFolderItWentTo() async throws {
        let browser = await browser()
        var changes = browser.folderChanges.changes().makeAsyncIterator()
        let notes = try await fileSystem.item(at: "doc2")
        let projects = try await fileSystem.item(at: "projects")

        await browser.drop(
            [notes], onto: projects, modifiers: [], resolver: ScriptedResolver(),
            undoManager: nil)

        #expect(await changes.next() == ["documents", "projects"])
    }

    @Test func movingToTheTrashNamesTheFolderItLeft() async {
        let browser = await browser()
        browser.setSelection(["invoices"], in: browser.layout.focusedPane.activeTabID)
        var changes = browser.folderChanges.changes().makeAsyncIterator()

        await browser.moveSelectionToTrash(undoManager: nil)

        #expect(await changes.next()?.contains("documents") == true)
    }

    @Test func undoAndRedoNameTheSameFolders() async throws {
        let browser = await browser()
        let undoManager = UndoManager()
        var changes = browser.folderChanges.changes().makeAsyncIterator()
        let notes = try await fileSystem.item(at: "doc2")
        let projects = try await fileSystem.item(at: "projects")
        await browser.drop(
            [notes], onto: projects, modifiers: [], resolver: ScriptedResolver(),
            undoManager: undoManager)
        _ = await changes.next()

        undoManager.undo()
        let undone = await changes.next()
        undoManager.redo()
        let redone = await changes.next()

        #expect(undone?.isSuperset(of: ["documents", "projects"]) == true)
        #expect(redone?.isSuperset(of: ["documents", "projects"]) == true)
    }

    @Test func everyWindowHearsTheChanges() async {
        let shared = FolderChanges()
        let browser = BrowserState(
            fileSystem: fileSystem, watcher: ManualFolderWatcher(), startFolder: "documents",
            folderChanges: shared)
        await browser.start()
        var other = shared.changes().makeAsyncIterator()

        await browser.createFolders(
            making: FolderTree(name: "Client", folders: []), in: "projects", undoManager: nil)

        #expect(await other.next() == ["projects"])
    }
}
