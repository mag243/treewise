import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Each half of a split window keeps its own view and sort order, as each has its own
/// column headers and view buttons (ADR 0154).
@MainActor
@Suite struct BrowserStatePaneLookTests {
    private func splitBrowser() async -> BrowserState {
        let browser = await makeBrowser()
        await browser.showSplitView()
        await browser.navigate(pane: 1, to: "downloads")
        return browser
    }

    @Test func theRightHalfStartsWithTheActiveHalfsViewAndSortOrder() async {
        let browser = await makeBrowser()
        browser.viewMode = .icons
        browser.sort(by: .size)

        await browser.showSplitView()

        #expect(browser.viewMode(of: 1) == .icons)
        #expect(browser.sort(of: 1) == browser.sort(of: 0))
    }

    @Test func changingTheActiveHalfsViewLeavesTheOtherHalfs() async {
        let browser = await splitBrowser()

        browser.viewMode = .icons

        #expect(browser.viewMode(of: 1) == .icons)
        #expect(browser.viewMode(of: 0) == .list)
    }

    @Test func sortingTheActiveHalfLeavesTheOtherHalfsOrder() async {
        let browser = await splitBrowser()
        let before = browser.sort(of: 0)

        browser.sort(by: .size)

        #expect(browser.sort(of: 1).column == .size)
        #expect(browser.sort(of: 0) == before)
    }

    @Test func aHalfsItemsFollowItsOwnSortOrder() async {
        let browser = await splitBrowser()
        browser.sort(by: .name, ascending: false)
        let right = browser.layout.panes[1].activeTabID

        let names = browser.visibleItems(of: right).map(\.name)

        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedDescending })
    }

    @Test func hidingSplitViewKeepsTheActiveHalfsViewAndSortOrder() async {
        let browser = await splitBrowser()
        browser.viewMode = .icons
        browser.sort(by: .size)

        browser.hideSplitView()

        #expect(browser.viewMode == .icons)
        #expect(browser.sort.column == .size)
    }

    @Test func aSplitWindowRestoresEachHalfsViewAndSortOrder() async {
        let browser = await splitBrowser()
        browser.viewMode = .icons
        browser.sort(by: .size)
        let restored = browser.snapshot.restored { _ in true }
        let again = await makeBrowser()

        if let restored { again.restore(restored) }

        #expect(again.viewMode(of: 0) == .list)
        #expect(again.viewMode(of: 1) == .icons)
        #expect(again.sort(of: 1).column == .size)
        #expect(again.sort(of: 0).column == .name)
    }

    @Test func aWindowSavedWithOneViewAndSortOrderGivesThemToBothHalves() throws {
        let saved = Data(
            """
            {"panes": [{"folders": ["documents"], "activeTab": 0},
                       {"folders": ["downloads"], "activeTab": 0}],
             "focusedPane": 0, "sortColumn": "size", "ascending": false, "viewMode": "icons"}
            """.utf8)

        let restored = try JSONDecoder().decode(WindowSnapshot.self, from: saved)
            .restored { _ in true }

        let expected = PaneLook(sort: ItemSort(column: .size, ascending: false), viewMode: .icons)
        #expect(restored?.paneLooks == [expected, expected])
    }
}
