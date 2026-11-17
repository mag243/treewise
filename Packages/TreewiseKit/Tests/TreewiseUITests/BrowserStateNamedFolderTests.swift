import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// New Folder on the iPad, which asks for the name before it makes the folder (ADR 0130).
@MainActor
@Suite struct BrowserStateNamedFolderTests {
    let fileSystem = ChangingFileSystem()
    private let english = Locale(identifier: "en")

    @Test func proposesAnUntitledNameNumberedWhenTaken() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        #expect(await browser.proposedNewFolderName(locale: english) == "untitled folder")
        _ = await browser.newFolder(named: "untitled folder", undoManager: nil)
        #expect(await browser.proposedNewFolderName(locale: english) == "untitled folder 2")
    }

    @Test func makesTheFolderWithTheNameAndSelectsItWithoutRenaming() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        let created = try #require(await browser.newFolder(named: "Receipts", undoManager: nil))
        #expect(created.name == "Receipts")
        #expect(
            browser.content(of: browser.layout.focusedPane.activeTabID).selection == [created.id])
        #expect(browser.renameRequest == nil)
    }

    @Test func saysWhyANameIsRefused() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        #expect(await browser.newFolder(named: "a/b", undoManager: nil) == nil)
        #expect(browser.failure == .invalidName("a/b"))
    }

    @Test func undoRemovesTheFolder() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        let undoManager = UndoManager()
        _ = await browser.newFolder(named: "Receipts", undoManager: undoManager)
        undoManager.undo()
        #expect(await eventually { !browser.focusedNames.contains("Receipts") })
    }
}
