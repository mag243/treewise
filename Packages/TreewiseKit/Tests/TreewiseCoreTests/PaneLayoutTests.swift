import Testing
import TreewiseCore

@Suite struct PaneLayoutTests {
    @Test func startsWithOneFocusedPane() {
        let layout = PaneLayout(at: "documents")
        #expect(!layout.isSplit)
        #expect(layout.focusedPane.activeTab.folder == "documents")
    }

    @Test func splittingAddsAFocusedSecondPane() {
        var layout = PaneLayout(at: "documents")
        layout.toggleSplit(newPaneAt: "downloads")
        #expect(layout.isSplit)
        #expect(layout.focusedPaneIndex == 1)
        #expect(layout.focusedPane.activeTab.folder == "downloads")
    }

    @Test func unsplittingMergesTheTabsOfBothPanesInOrder() {
        var layout = PaneLayout(at: "documents")
        layout.updateFocusedPane { $0.openTab(at: "projects") }
        layout.toggleSplit(newPaneAt: "downloads")

        layout.toggleSplit(newPaneAt: "home")

        #expect(!layout.isSplit)
        #expect(layout.focusedPaneIndex == 0)
        #expect(layout.panes[0].tabs.map(\.folder) == ["documents", "projects", "downloads"])
    }

    @Test func unsplittingKeepsTheActiveTabOfTheFocusedPane() {
        var layout = PaneLayout(at: "documents")
        layout.toggleSplit(newPaneAt: "downloads")
        layout.focusPane(at: 0)

        layout.toggleSplit(newPaneAt: "home")

        #expect(layout.focusedPane.activeTab.folder == "documents")
    }

    @Test func switchesFocusBetweenPanes() {
        var layout = PaneLayout(at: "documents")
        layout.toggleSplit(newPaneAt: "downloads")
        let focused = layout.focusPane(at: 0)
        #expect(focused)
        #expect(layout.focusedPane.activeTab.folder == "documents")
    }

    @Test func refusesToFocusAPaneThatDoesNotExist() {
        var layout = PaneLayout(at: "documents")
        let focused = layout.focusPane(at: 1)
        #expect(!focused)
        #expect(layout.focusedPaneIndex == 0)
    }

    @Test func changesATabInAPaneWithoutFocus() {
        var layout = PaneLayout(at: "documents")
        let left = layout.focusedPane.activeTabID
        layout.toggleSplit(newPaneAt: "downloads")

        let changed = layout.updateTab(left) { $0.history.navigate(to: "invoices") }

        #expect(changed)
        #expect(layout.panes[0].activeTab.folder == "invoices")
        #expect(layout.focusedPaneIndex == 1)
    }

    @Test func findsATabInAnyPane() {
        var layout = PaneLayout(at: "documents")
        let left = layout.focusedPane.activeTabID
        layout.toggleSplit(newPaneAt: "downloads")
        #expect(layout.tab(left)?.folder == "documents")
        #expect(layout.tab(TabModel(at: "home").id) == nil)
    }

    @Test func refusesToChangeAnUnknownTab() {
        var layout = PaneLayout(at: "documents")
        let changed = layout.updateTab(TabModel(at: "home").id) { $0.history.navigate(to: "x") }
        #expect(!changed)
    }

    @Test func hasNoPaneAtAnIndexThatSplitViewRemoved() {
        var layout = PaneLayout(at: "home")
        layout.toggleSplit(newPaneAt: "downloads")
        #expect(layout.pane(at: 1)?.activeTab.folder == "downloads")
        layout.toggleSplit(newPaneAt: "downloads")
        #expect(layout.pane(at: 1) == nil)
    }

    @Test func closesAPaneOfASplitAndFocusesTheOther() {
        var layout = PaneLayout(at: "documents")
        layout.toggleSplit(newPaneAt: "home")

        let closed = layout.closePane(at: 0)
        #expect(closed)
        #expect(!layout.isSplit)
        #expect(layout.focusedPane.activeTab.folder == "home")
    }

    @Test func keepsTheOnlyPane() {
        var layout = PaneLayout(at: "documents")
        let closed = layout.closePane(at: 0)
        #expect(!closed)
        #expect(layout.panes.count == 1)
    }

    @Test func makesALayoutFromPanes() {
        let layout = PaneLayout(
            panes: [PaneModel(at: "documents"), PaneModel(at: "downloads")], focused: 1)
        #expect(layout.isSplit)
        #expect(layout.focusedPane.activeTab.folder == "downloads")
    }
}
