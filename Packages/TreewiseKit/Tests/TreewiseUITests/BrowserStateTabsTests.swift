import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

@MainActor
@Suite struct BrowserStateTabsTests {
    @Test func opensAndClosesTabs() async {
        let browser = await makeBrowser()
        await browser.openTab(pane: 0, at: "downloads")
        #expect(browser.focusedFolder == "downloads")
        #expect(browser.focusedNames.contains("Installer.dmg"))

        browser.closeTab(pane: 0, tab: browser.layout.focusedPane.activeTabID)
        #expect(browser.focusedFolder == "documents")
    }

    @Test func showsTheNextAndThePreviousTab() async {
        let browser = await makeBrowser()
        await browser.openTab(pane: 0, at: "downloads")

        await browser.showNextTab()
        #expect(browser.focusedFolder == "documents")
        await browser.showPreviousTab()
        #expect(browser.focusedFolder == "downloads")
        #expect(browser.focusedNames.contains("Installer.dmg"))
    }

    @Test func closesTheActiveTab() async {
        let browser = await makeBrowser()
        await browser.openTab(pane: 0, at: "downloads")
        #expect(browser.closeActiveTab() == .tab)
        #expect(browser.focusedFolder == "documents")
    }

    @Test func closesAPaneOfASplitWithItsLastTab() async {
        let browser = await makeBrowser()
        await browser.toggleSplit(newPaneAt: "downloads")
        #expect(browser.closeActiveTab() == .pane)
        #expect(!browser.layout.isSplit)
        #expect(browser.focusedFolder == "documents")
    }

    @Test func leavesTheLastTabOfTheWindowForTheWindowToClose() async {
        let browser = await makeBrowser()
        #expect(browser.closeActiveTab() == .window)
        #expect(browser.layout.focusedPane.tabs.count == 1)
    }

    @Test func splitsIntoTwoLoadedPanesAndMergesThemAgain() async {
        let browser = await makeBrowser()
        await browser.toggleSplit(newPaneAt: "downloads")
        #expect(browser.layout.isSplit)
        #expect(browser.focusedNames.contains("Installer.dmg"))

        await browser.toggleSplit(newPaneAt: "home")
        #expect(browser.layout.panes[0].tabs.map(\.folder) == ["documents", "downloads"])
    }

    @Test func keepsASelectionPerTab() async {
        let browser = await makeBrowser()
        let first = browser.layout.focusedPane.activeTabID
        browser.select("doc2", in: first, extending: false)
        await browser.openTab(pane: 0, at: "documents")
        let second = browser.layout.focusedPane.activeTabID

        #expect(browser.content(of: first).selection == ["doc2"])
        #expect(browser.content(of: second).selection.isEmpty)
    }

    @Test func extendsOrReplacesTheSelection() async {
        let browser = await makeBrowser()
        let tab = browser.layout.focusedPane.activeTabID
        browser.select("doc1", in: tab, extending: false)
        browser.select("doc2", in: tab, extending: true)
        #expect(browser.content(of: tab).selection == ["doc1", "doc2"])
        browser.select("doc2", in: tab, extending: true)
        #expect(browser.content(of: tab).selection == ["doc1"])
        browser.select("doc3", in: tab, extending: false)
        #expect(browser.content(of: tab).selection == ["doc3"])
    }

    @Test func clearsSelectionAndSearchWhenNavigating() async {
        let browser = await makeBrowser()
        let tab = browser.layout.focusedPane.activeTabID
        browser.select("doc2", in: tab, extending: false)
        browser.setQuery("notes", in: tab)
        await browser.navigate(pane: 0, to: "invoices")
        #expect(browser.content(of: tab).selection.isEmpty)
        #expect(browser.content(of: tab).query.isEmpty)
    }

    @Test func filtersTheListBySearchText() async {
        let browser = await makeBrowser()
        browser.setQuery("NOTES", in: browser.layout.focusedPane.activeTabID)
        #expect(browser.focusedNames == ["Notes.md"])
    }

    @Test func sortsByTheChosenColumn() async {
        let browser = await makeBrowser()
        browser.sort(by: .size)
        #expect(browser.sort == ItemSort(column: .size))
        #expect(browser.focusedNames.suffix(2) == ["Lease agreement.pdf", "Presentation.key"])
        browser.sort(by: .size)
        #expect(browser.focusedNames.prefix(3) == ["Manuals", "Invoices", "Presentation.key"])
    }

    @Test func sortsByAColumnInAChosenDirection() async {
        let browser = await makeBrowser()
        browser.sort(by: .size, ascending: false)
        browser.sort(by: .size, ascending: false)
        #expect(
            browser.sort == ItemSort(column: .size, ascending: false), "choosing it again keeps it")
        browser.sort(by: .name, ascending: false)
        #expect(browser.sort == ItemSort(column: .name, ascending: false))
    }

    @Test func takesTheWholeSelectionFromTheList() async {
        let browser = await makeBrowser()
        let tab = browser.layout.focusedPane.activeTabID
        browser.setSelection(["doc1", "doc2", "gone"], in: tab)
        #expect(browser.content(of: tab).selection == ["doc1", "doc2"])
    }

    @Test func startsWithARestoredLayoutAndDescribesIt() async {
        var left = PaneModel(at: "documents")
        left.openTab(at: "downloads")
        let restored = PaneLayout(panes: [left], focused: 0)
        let browser = BrowserState(
            fileSystem: Fixture.standard, watcher: ManualFolderWatcher(), startFolder: "home")
        browser.restore(restored, sort: ItemSort(column: .kind), viewMode: .icons)
        await browser.start()

        #expect(browser.focusedNames.contains("Installer.dmg"))
        #expect(
            browser.snapshot
                == WindowSnapshot(layout: restored, sort: ItemSort(column: .kind), viewMode: .icons)
        )
    }
}
