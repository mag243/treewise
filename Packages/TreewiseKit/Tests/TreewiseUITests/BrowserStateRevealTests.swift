import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// What Treewise selects after making or renaming it is brought into view; a
/// selection the user makes is left where it is.
@MainActor
@Suite struct BrowserStateRevealTests {
    let fileSystem = ChangingFileSystem()

    private func browser() async throws -> BrowserState {
        let documents = try await fileSystem.item(at: "documents")
        fileSystem.add(
            FileItem(
                id: "zip", name: "Photos.zip", kind: .file, parentID: "documents",
                volume: documents.volume))
        return await makeBrowser(fileSystem: fileSystem)
    }

    private func select(_ ids: Set<FileItem.ID>, in browser: BrowserState) {
        browser.setSelection(ids, in: browser.layout.focusedPane.activeTabID)
    }

    @Test func revealsANewArchive() async throws {
        let browser = try await browser()
        select(["doc2"], in: browser)

        await browser.compressSelection(to: .zip, undoManager: nil)

        let created = try #require(browser.selectedItems.first)
        #expect(browser.revealRequest == created.id)
    }

    @Test func revealsAnExtractedFolder() async throws {
        let browser = try await browser()
        select(["zip"], in: browser)

        await browser.extractSelection(to: "documents", undoManager: nil)

        let created = try #require(browser.selectedItems.first)
        #expect(browser.revealRequest == created.id)
    }

    @Test func revealsANewFolder() async throws {
        let browser = try await browser()

        let created = try #require(
            await browser.newFolder(undoManager: nil, locale: Locale(identifier: "en")))

        #expect(browser.revealRequest == created.id)
    }

    @Test func revealsARenamedItem() async throws {
        let browser = try await browser()
        let notes = try await fileSystem.item(at: "doc2")

        await browser.rename(notes, to: "Ideas.md", undoManager: nil)

        let renamed = try #require(browser.selectedItems.first)
        #expect(renamed.name == "Ideas.md")
        #expect(browser.revealRequest == renamed.id)
    }

    @Test func leavesASelectionByTheUserWhereItIs() async throws {
        let browser = try await browser()

        select(["doc2"], in: browser)

        #expect(browser.revealRequest == nil)
    }

    @Test func revealsNothingWhenTheArchiveCannotBeMade() async throws {
        let browser = try await browser()
        select(["doc2"], in: browser)
        fileSystem.failChanges(with: FileSystemError.notWritable("documents"))

        await browser.compressSelection(to: .zip, undoManager: nil)

        #expect(browser.failure != nil)
        #expect(browser.revealRequest == nil)
    }
}
