import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// What a rename request names, as the iPad's alert finds it.
@MainActor
@Suite struct BrowserStateRenameTargetTests {
    let fileSystem = ChangingFileSystem()

    /// A search the new folder does not match hides it from the list, but the iPad's alert
    /// still finds what to rename (audit 2026-11, A21).
    @Test func findsTheItemToRenameWhileASearchHidesIt() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")
        let tab = browser.layout.focusedPane.activeTabID
        browser.setQuery("Notes", in: tab)
        let created = try #require(
            await browser.newFolder(undoManager: nil, locale: Locale(identifier: "en")))

        #expect(!browser.visibleItems(of: tab).contains { $0.id == created.id })
        #expect(browser.renameTarget?.id == created.id)
    }

    @Test func namesNothingWithoutARequest() async {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")
        #expect(browser.renameTarget == nil)
    }
}
