import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

@MainActor
@Suite struct BrowserStateNavigationTests {
    @Test func startsByLoadingTheSidebarAndTheFirstFolder() async {
        let browser = await makeBrowser()
        #expect(browser.favorites.map(\.name).first == "Applications")
        #expect(browser.locations.map(\.id) == ["hd", "icloud", "usb"])
        #expect(browser.focusedNames.prefix(2) == ["Invoices", "Manuals"])
    }

    @Test func navigatesToAFolder() async {
        let browser = await makeBrowser()
        await browser.navigate(pane: 0, to: "invoices")
        #expect(browser.focusedNames == ["Invoice 2026-08.pdf", "Invoice 2026-09.pdf"])
    }

    @Test func refreshesWhatTheFolderShows() async {
        let fileSystem = ChangingFileSystem()
        let browser = await makeBrowser(fileSystem: fileSystem)
        fileSystem.remove("doc2")
        #expect(browser.focusedNames.contains("Notes.md"), "no watcher told the window")

        await browser.refresh(pane: 0)

        #expect(!browser.focusedNames.contains("Notes.md"))
        #expect(browser.focusedFolder == "documents", "it stays in the folder")
    }

    @Test func goesBackForwardAndUp() async {
        let browser = await makeBrowser()
        await browser.navigate(pane: 0, to: "invoices")

        await browser.goBack(pane: 0)
        #expect(browser.focusedFolder == "documents")
        await browser.goForward(pane: 0)
        #expect(browser.focusedFolder == "invoices")
        await browser.goUp(pane: 0)
        #expect(browser.focusedFolder == "documents")
    }

    @Test func opensAFolderInTheSameTab() async throws {
        let browser = await makeBrowser()
        let invoices = try #require(Fixture.standard["invoices"])
        let result = await browser.open(invoices, pane: 0, in: .samePane)
        #expect(result == .navigated)
        #expect(browser.focusedFolder == "invoices")
        #expect(browser.layout.focusedPane.tabs.count == 1)
    }

    @Test func opensAFolderInANewTab() async throws {
        let browser = await makeBrowser()
        let invoices = try #require(Fixture.standard["invoices"])
        await browser.open(invoices, pane: 0, in: .newTab)
        #expect(browser.layout.focusedPane.tabs.map(\.folder) == ["documents", "invoices"])
        #expect(browser.focusedNames.count == 2)
    }

    @Test func opensAFolderInTheOtherPane() async throws {
        let browser = await makeBrowser()
        await browser.toggleSplit(newPaneAt: "downloads")
        let invoices = try #require(Fixture.standard["invoices"])

        await browser.open(invoices, pane: 0, in: .otherPane)

        #expect(browser.layout.panes[0].activeTab.folder == "documents")
        #expect(browser.layout.panes[1].activeTab.folder == "invoices")
    }

    @Test func opensAFolderInTheSamePaneWhenThereIsNoOther() async throws {
        let browser = await makeBrowser()
        let invoices = try #require(Fixture.standard["invoices"])
        await browser.open(invoices, pane: 0, in: .otherPane)
        #expect(browser.focusedFolder == "invoices")
    }

    @Test func handsFilesBackToBeOpenedByTheApp() async throws {
        let browser = await makeBrowser()
        let notes = try #require(Fixture.standard["doc2"])
        #expect(await browser.open(notes, pane: 0, in: .samePane) == .openFile(notes))
        #expect(browser.focusedFolder == "documents")
    }

    @Test func reportsAFolderThatCannotBeRead() async {
        let browser = await makeBrowser()
        await browser.navigate(pane: 0, to: "nowhere")
        let tab = browser.layout.focusedPane.activeTabID
        #expect(browser.content(of: tab).failure == .notFound("nowhere"))
        #expect(browser.focusedNames.isEmpty)
    }

    @Test func knowsTheFolderATabShows() async {
        let browser = await makeBrowser()
        let tab = browser.layout.focusedPane.activeTabID
        #expect(browser.content(of: tab).folder?.name == "Documents")
    }

    @Test func knowsWhetherAPaneCanGoUp() async {
        let browser = await makeBrowser()
        #expect(browser.canGoUp(pane: 0))
        await browser.navigate(pane: 0, to: "hd")
        #expect(!browser.canGoUp(pane: 0))
    }

    @Test func opensNewTabsAtHome() async {
        let browser = BrowserState(
            fileSystem: Fixture.standard, watcher: ManualFolderWatcher(), startFolder: "documents",
            homeFolder: "home")
        await browser.start()
        await browser.openTab(pane: 0, at: browser.homeFolder)
        #expect(browser.focusedFolder == "home")
    }

    @Test func treatsTheStartFolderAsHomeByDefault() async {
        let browser = await makeBrowser()
        #expect(browser.homeFolder == "documents")
    }

    @Test func readsAnItemThroughItsFileSystem() async throws {
        let browser = await makeBrowser()
        #expect(try await browser.item(at: "doc2").name == "Notes.md")
    }
}
