import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Split View in a window on the Mac: two folders side by side, the active half acted on,
/// and the window's title naming both (ADR 0154).
@MainActor
@Suite struct BrowserStateSplitViewTests {
    @Test func showingSplitViewOpensAFocusedRightHalfOnTheActiveFolder() async {
        let browser = await makeBrowser()

        await browser.showSplitView()

        #expect(browser.layout.isSplit)
        #expect(browser.layout.focusedPaneIndex == 1)
        #expect(browser.layout.panes.map(\.activeTab.folder) == ["documents", "documents"])
        #expect(!browser.focusedNames.isEmpty)
    }

    @Test func showingSplitViewAgainKeepsTheTwoHalves() async {
        let browser = await makeBrowser()
        await browser.showSplitView()
        await browser.navigate(pane: 1, to: "downloads")

        await browser.showSplitView()

        #expect(browser.layout.panes.map(\.activeTab.folder) == ["documents", "downloads"])
    }

    @Test(arguments: [(0, FileItem.ID("documents")), (1, FileItem.ID("downloads"))])
    func hidingSplitViewKeepsTheActiveHalfsFolder(active: Int, kept: FileItem.ID) async {
        let browser = await makeBrowser()
        await browser.showSplitView()
        await browser.navigate(pane: 1, to: "downloads")
        browser.focusPane(active)

        browser.hideSplitView()

        #expect(!browser.layout.isSplit)
        #expect(browser.layout.panes.map(\.tabs.count) == [1])
        #expect(browser.focusedFolder == kept)
    }

    @Test func hidingSplitViewWithoutASplitChangesNothing() async {
        let browser = await makeBrowser()

        browser.hideSplitView()

        #expect(browser.layout.panes.map(\.activeTab.folder) == ["documents"])
    }

    @Test func theTitleNamesTheFolder() async {
        let browser = await makeBrowser()

        #expect(browser.windowTitle == "Documents")
    }

    @Test func aSplitWindowsTitleNamesBothFoldersLeftFirst() async {
        let browser = await makeBrowser()
        await browser.showSplitView()
        await browser.navigate(pane: 1, to: "downloads")

        #expect(browser.windowTitle == "Documents | Downloads")
    }

    @Test func aSplitWindowRestoresSplitWithBothFoldersAndItsActiveHalf() async {
        let browser = await makeBrowser()
        await browser.showSplitView()
        await browser.navigate(pane: 1, to: "downloads")
        browser.focusPane(0)

        let restored = browser.snapshot.restored { _ in true }

        #expect(restored?.layout.panes.map(\.activeTab.folder) == ["documents", "downloads"])
        #expect(restored?.layout.focusedPaneIndex == 0)
    }
}
