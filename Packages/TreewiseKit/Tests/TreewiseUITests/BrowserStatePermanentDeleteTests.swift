import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Where a location has no Trash, the items Move to Trash could not move can be deleted
/// for good, which the user confirms (ADR 0128).
@MainActor
@Suite struct BrowserStatePermanentDeleteTests {
    private func trashingWithoutATrash() async -> (BrowserState, ChangingFileSystem) {
        let fileSystem = ChangingFileSystem()
        let browser = await makeBrowser(fileSystem: fileSystem)
        browser.setSelection(["doc2"], in: browser.layout.focusedPane.activeTabID)
        fileSystem.failChanges(with: FileSystemError.trashUnavailable("doc2"))
        await browser.moveSelectionToTrash(undoManager: nil)
        return (browser, fileSystem)
    }

    @Test func offersTheItemsMoveToTrashCouldNotMoveForWantOfATrash() async {
        let (browser, _) = await trashingWithoutATrash()

        #expect(browser.failure == .trashUnavailable("doc2"))
        #expect(browser.itemsWithoutTrash.map(\.id) == ["doc2"])
    }

    /// The alert is built as the failure shows, and keeps the buttons it was built with.
    @Test func offersThemAsTheFailureShowsNotOnceTheFolderIsReadAgain() async {
        let fileSystem = ChangingFileSystem()
        let browser = await makeBrowser(fileSystem: fileSystem)
        browser.setSelection(["doc2"], in: browser.layout.focusedPane.activeTabID)
        fileSystem.failChanges(with: FileSystemError.trashUnavailable("doc2"))
        fileSystem.holdNextListing()

        let trashing = Task { await browser.moveSelectionToTrash(undoManager: nil) }
        #expect(await eventually { fileSystem.heldListingCount == 1 })

        #expect(browser.failure == .trashUnavailable("doc2"))
        #expect(browser.itemsWithoutTrash.map(\.id) == ["doc2"])
        fileSystem.releaseListings()
        await trashing.value
    }

    @Test func offersNothingWhenTrashingFailsForAnotherReason() async {
        let fileSystem = ChangingFileSystem()
        let browser = await makeBrowser(fileSystem: fileSystem)
        browser.setSelection(["doc2"], in: browser.layout.focusedPane.activeTabID)
        fileSystem.failChanges(with: FileSystemError.notWritable("doc2"))

        await browser.moveSelectionToTrash(undoManager: nil)

        #expect(browser.failure == .notWritable("doc2"))
        #expect(browser.itemsWithoutTrash.isEmpty)
    }

    @Test func deletesThemForGoodAndForgetsThem() async {
        let (browser, fileSystem) = await trashingWithoutATrash()
        fileSystem.failChanges(with: nil)

        await browser.deletePermanently(browser.itemsWithoutTrash)

        #expect(!browser.focusedNames.contains("Notes.md"))
        #expect(browser.itemsWithoutTrash.isEmpty)
        #expect(browser.failure == nil)
    }

    @Test func forgetsThemWhenTheFailureIsCleared() async {
        let (browser, _) = await trashingWithoutATrash()

        browser.clearFailure()

        #expect(browser.itemsWithoutTrash.isEmpty)
    }
}
