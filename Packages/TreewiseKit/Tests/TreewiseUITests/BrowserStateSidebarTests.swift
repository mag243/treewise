import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

@MainActor
@Suite struct BrowserStateSidebarTests {
    @Test func listsTheSubfoldersOfAFolderByName() async {
        let browser = await makeBrowser()
        let names = await browser.subfolders(of: "home").map(\.name)
        #expect(
            names == [
                "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Projects",
            ])
    }

    @Test func leavesFilesOutOfTheTree() async {
        let browser = await makeBrowser()
        #expect(await browser.subfolders(of: "invoices").isEmpty)
    }

    @Test func showsNothingForAFolderThatCannotBeRead() async {
        let browser = await makeBrowser()
        #expect(await browser.subfolders(of: "nowhere").isEmpty)
    }
}

@MainActor
@Suite struct BrowserStateLocationShownTests {
    @Test func aFolderIsInTheLocationAboveIt() async {
        let browser = await makeBrowser(at: "documents")
        #expect(browser.locationShown(in: 0) == "hd")
    }

    @Test func aLocationShownIsItsOwnLocation() async {
        let browser = await makeBrowser(at: "icloud")
        #expect(browser.locationShown(in: 0) == "icloud")
    }

    @Test func aFolderOutsideEveryLocationIsInNone() async {
        let browser = await makeBrowser(at: "nowhere")
        #expect(browser.locationShown(in: 0) == nil)
    }
}
