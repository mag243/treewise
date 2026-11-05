import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

@MainActor
@Suite struct BrowserStateLiveTests {
    @Test func watchesTheFoldersThePanesShow() async {
        let watcher = ManualFolderWatcher()
        let browser = await makeBrowser(watcher: watcher)
        await browser.toggleSplit(newPaneAt: "downloads")
        // This Mac, for the sidebar's Locations (ADR 0044), and the panes' folders.
        #expect(
            await eventually { watcher.watchedFolders == [.computer, "documents", "downloads"] })
    }

    @Test func reloadsAFolderWhenItChanges() async {
        let fileSystem = ChangingFileSystem()
        let watcher = ManualFolderWatcher()
        let browser = await makeBrowser(fileSystem: fileSystem, watcher: watcher)
        #expect(await eventually { watcher.watchedFolders.contains("documents") })

        fileSystem.add(
            FileItem(id: "new", name: "New.txt", kind: .file, parentID: "documents", volume: "hd"))
        watcher.change("documents")

        #expect(await eventually { browser.focusedNames.contains("New.txt") })
    }

    @Test func movesATabWhoseFolderWasDeletedToTheNearestFolderLeft() async {
        let fileSystem = ChangingFileSystem()
        let watcher = ManualFolderWatcher()
        let browser = await makeBrowser(fileSystem: fileSystem, watcher: watcher, at: "invoices")
        #expect(await eventually { watcher.watchedFolders.contains("invoices") })

        fileSystem.remove("documents")
        watcher.change("invoices")

        #expect(await eventually { browser.focusedFolder == "home" })
        #expect(await eventually { browser.focusedNames.contains("Desktop") })
    }

    @Test func reportsTheItemCountAndFreeSpaceForTheStatusBar() async {
        let browser = await makeBrowser()
        let tab = browser.layout.focusedPane.activeTabID
        #expect(browser.content(of: tab).items.count == 6)
        #expect(browser.content(of: tab).availableCapacity == 245_300_000_000)
    }
}
