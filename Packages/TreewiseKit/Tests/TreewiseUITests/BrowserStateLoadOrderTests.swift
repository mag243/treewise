import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// A folder that changes while it is being read, as an archive does when a
/// change to it ends while its listing is still read.
@MainActor
@Suite struct BrowserStateLoadOrderTests {
    @Test func watchesAFolderWhileItIsStillBeingRead() async {
        let fileSystem = ChangingFileSystem()
        let watcher = ManualFolderWatcher()
        let browser = await makeBrowser(fileSystem: fileSystem, watcher: watcher)
        fileSystem.holdNextListing()

        let opening = Task { await browser.navigate(pane: 0, to: "downloads") }
        #expect(await eventually { fileSystem.heldListingCount == 1 })

        // A change from now on would be missed by a watch that starts after the reading.
        #expect(watcher.watchedFolders.contains("downloads"))
        fileSystem.releaseListings()
        await opening.value
    }

    @Test func keepsTheNewerListingWhenAnOlderOneEndsLater() async {
        let fileSystem = ChangingFileSystem()
        let browser = await makeBrowser(fileSystem: fileSystem)
        fileSystem.holdNextListing()
        let opening = Task { await browser.navigate(pane: 0, to: "downloads") }
        #expect(await eventually { fileSystem.heldListingCount == 1 })

        fileSystem.add(
            FileItem(id: "new", name: "New.txt", kind: .file, parentID: "downloads", volume: "hd"))
        await browser.refresh(pane: 0)
        #expect(browser.focusedNames.contains("New.txt"))
        fileSystem.releaseListings()
        await opening.value

        #expect(browser.focusedNames.contains("New.txt"), "the older listing is dropped")
    }
}
