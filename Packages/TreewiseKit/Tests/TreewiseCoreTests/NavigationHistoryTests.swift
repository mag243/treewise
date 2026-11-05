import Testing
import TreewiseCore

@Suite struct NavigationHistoryTests {
    @Test func startsWithoutBackOrForward() {
        let history = NavigationHistory(at: "home")
        #expect(history.current == "home")
        #expect(!history.canGoBack && !history.canGoForward)
    }

    @Test func navigatingPushesTheCurrentFolderOnTheBackStack() {
        var history = NavigationHistory(at: "home")
        history.navigate(to: "documents")
        #expect(history.current == "documents")
        #expect(history.backStack == ["home"])
    }

    @Test func navigatingToTheCurrentFolderChangesNothing() {
        var history = NavigationHistory(at: "home")
        history.navigate(to: "home")
        #expect(!history.canGoBack)
    }

    @Test func goesBackAndForward() {
        var history = NavigationHistory(at: "home")
        history.navigate(to: "documents")
        history.navigate(to: "invoices")

        let wentBack = history.goBack()
        #expect(wentBack)
        #expect(history.current == "documents")
        #expect(history.forwardStack == ["invoices"])

        let wentForward = history.goForward()
        #expect(wentForward)
        #expect(history.current == "invoices")
        #expect(history.backStack == ["home", "documents"])
    }

    @Test func refusesToGoPastEitherEnd() {
        var history = NavigationHistory(at: "home")
        let wentBack = history.goBack()
        #expect(!wentBack)
        let wentForward = history.goForward()
        #expect(!wentForward)
        #expect(history.current == "home")
    }

    @Test func newNavigationClearsTheForwardStack() {
        var history = NavigationHistory(at: "home")
        history.navigate(to: "documents")
        history.goBack()
        history.navigate(to: "downloads")
        #expect(!history.canGoForward)
        #expect(history.backStack == ["home"])
    }

    @Test func goesUpToTheEnclosingFolder() {
        var history = NavigationHistory(at: "invoices")
        let parents: [FileItem.ID: FileItem.ID] = ["invoices": "documents"]
        let movedUp = history.goUp { parents[$0] }
        #expect(movedUp)
        #expect(history.current == "documents")
        #expect(history.backStack == ["invoices"])
    }

    @Test func cannotGoUpFromATopLevelLocation() {
        var history = NavigationHistory(at: "hd")
        let movedUp = history.goUp { _ in nil }
        #expect(!movedUp)
        #expect(history.current == "hd")
    }

    @Test func keepsAtMostTheMaximumNumberOfBackEntries() {
        var history = NavigationHistory(at: "f0")
        let steps = NavigationHistory.maximumBackEntries + 5
        for step in 1...steps {
            history.navigate(to: FileItem.ID("f\(step)"))
        }
        #expect(history.backStack.count == NavigationHistory.maximumBackEntries)
        #expect(history.backStack.first == "f5")
    }

    @Test func dropsRemovedFoldersFromBothStacks() {
        var history = NavigationHistory(at: "home")
        history.navigate(to: "documents")
        history.navigate(to: "invoices")
        history.navigate(to: "downloads")
        history.goBack()

        history.removeItems(["documents"], fallback: "home")

        #expect(history.backStack == ["home"])
        #expect(history.current == "invoices")
        #expect(history.forwardStack == ["downloads"])
    }

    @Test func movesToTheFallbackWhenTheCurrentFolderIsRemoved() {
        var history = NavigationHistory(at: "home")
        history.navigate(to: "documents")
        history.navigate(to: "invoices")

        history.removeItems(["invoices"], fallback: "documents")

        #expect(history.current == "documents")
        #expect(history.backStack == ["home"])
    }

    @Test func collapsesEntriesThatBecomeNeighboursAfterARemoval() {
        var history = NavigationHistory(at: "home")
        history.navigate(to: "documents")
        history.navigate(to: "home")
        history.navigate(to: "downloads")

        history.removeItems(["documents"], fallback: "home")

        #expect(history.backStack == ["home"])
    }
}
