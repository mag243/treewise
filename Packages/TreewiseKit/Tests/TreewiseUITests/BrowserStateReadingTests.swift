import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// A folder that takes long to read, as a large cloud folder does (ADR 0121): the tab says
/// it is reading while it opens a folder, not while it reads the one it shows again.
@MainActor
@Suite struct BrowserStateReadingTests {
    @Test func readsAFolderItOpensUntilItsListingEnds() async {
        let fileSystem = ChangingFileSystem()
        let browser = await makeBrowser(fileSystem: fileSystem)
        let tab = browser.layout.focusedPane.activeTabID
        fileSystem.holdNextListing()

        let opening = Task { await browser.navigate(pane: 0, to: "downloads") }
        #expect(await eventually { fileSystem.heldListingCount == 1 })

        #expect(browser.isReading(tab))
        fileSystem.releaseListings()
        await opening.value
        #expect(!browser.isReading(tab))
    }

    @Test func readingTheShownFolderAgainKeepsItsList() async {
        let fileSystem = ChangingFileSystem()
        let browser = await makeBrowser(fileSystem: fileSystem)
        let tab = browser.layout.focusedPane.activeTabID
        fileSystem.holdNextListing()

        let refreshing = Task { await browser.refresh(pane: 0) }
        #expect(await eventually { fileSystem.heldListingCount == 1 })

        #expect(!browser.isReading(tab))
        fileSystem.releaseListings()
        await refreshing.value
    }
}
