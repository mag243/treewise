import Testing
import TreewiseCore

@Suite struct PaneModelTests {
    @Test func startsWithOneActiveTab() {
        let pane = PaneModel(at: "documents")
        #expect(pane.tabs.count == 1)
        #expect(pane.activeTab.folder == "documents")
    }

    @Test func opensANewTabAndMakesItActive() {
        var pane = PaneModel(at: "documents")
        let id = pane.openTab(at: "home")
        #expect(pane.tabs.map(\.folder) == ["documents", "home"])
        #expect(pane.activeTabID == id)
    }

    @Test func activatesAnExistingTab() {
        var pane = PaneModel(at: "documents")
        let first = pane.activeTabID
        pane.openTab(at: "home")
        let activated = pane.activateTab(first)
        #expect(activated)
        #expect(pane.activeTab.folder == "documents")
    }

    @Test func refusesToActivateAnUnknownTab() {
        var pane = PaneModel(at: "documents")
        let stranger = TabModel(at: "home").id
        let activated = pane.activateTab(stranger)
        #expect(!activated)
    }

    @Test func keepsTheLastTab() {
        var pane = PaneModel(at: "documents")
        let closed = pane.closeTab(pane.activeTabID)
        #expect(!closed)
        #expect(pane.tabs.count == 1)
    }

    @Test func activatesTheTabBeforeAClosedActiveTab() {
        var pane = PaneModel(at: "documents")
        pane.openTab(at: "home")
        let third = pane.openTab(at: "downloads")
        let closed = pane.closeTab(third)
        #expect(closed)
        #expect(pane.activeTab.folder == "home")
    }

    @Test func activatesTheNextTabWhenTheFirstActiveTabCloses() {
        var pane = PaneModel(at: "documents")
        let first = pane.activeTabID
        pane.openTab(at: "home")
        pane.activateTab(first)
        let closed = pane.closeTab(first)
        #expect(closed)
        #expect(pane.activeTab.folder == "home")
    }

    @Test func keepsTheActiveTabWhenAnotherTabCloses() {
        var pane = PaneModel(at: "documents")
        let first = pane.activeTabID
        pane.openTab(at: "home")
        let closed = pane.closeTab(first)
        #expect(closed)
        #expect(pane.activeTab.folder == "home")
    }

    @Test func changesTheActiveTab() {
        var pane = PaneModel(at: "documents")
        pane.updateActiveTab { $0.history.navigate(to: "invoices") }
        #expect(pane.activeTab.folder == "invoices")
    }

    @Test func activatesTheNextTabAndWrapsAround() {
        var pane = PaneModel(at: "documents")
        let first = pane.activeTabID
        let second = pane.openTab(at: "home")
        pane.activateTab(first)

        pane.activateNextTab()
        #expect(pane.activeTabID == second)
        pane.activateNextTab()
        #expect(pane.activeTabID == first)
    }

    @Test func activatesThePreviousTabAndWrapsAround() {
        var pane = PaneModel(at: "documents")
        let first = pane.activeTabID
        let second = pane.openTab(at: "home")
        pane.activateTab(first)

        pane.activatePreviousTab()
        #expect(pane.activeTabID == second)
        pane.activatePreviousTab()
        #expect(pane.activeTabID == first)
    }
}
