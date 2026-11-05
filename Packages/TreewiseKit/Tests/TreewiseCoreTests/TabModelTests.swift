import Testing
import TreewiseCore

@Suite struct TabModelTests {
    @Test func startsAtItsFolderWithAnEmptyHistory() {
        let tab = TabModel(at: "documents")
        #expect(tab.folder == "documents")
        #expect(!tab.history.canGoBack)
    }

    @Test func givesEveryTabItsOwnIdentity() {
        #expect(TabModel(at: "home").id != TabModel(at: "home").id)
    }

    @Test func followsItsHistory() {
        var tab = TabModel(at: "home")
        tab.history.navigate(to: "downloads")
        #expect(tab.folder == "downloads")
    }
}
