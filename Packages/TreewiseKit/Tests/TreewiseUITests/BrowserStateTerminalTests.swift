import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Which folder Open in Terminal opens (ADR 0052).
@MainActor
@Suite struct BrowserStateTerminalTests {
    private func browser(
        at folder: FileItem.ID = "documents", selecting ids: Set<FileItem.ID> = []
    ) async -> BrowserState {
        let browser = await makeBrowser(at: folder)
        browser.setSelection(ids, in: browser.layout.focusedPane.activeTabID)
        return browser
    }

    @Test func opensTheFolderShownWithoutASelection() async {
        #expect(await browser().terminalFolder == "documents")
    }

    @Test func opensASelectedFolder() async {
        #expect(await browser(at: "home", selecting: ["projects"]).terminalFolder == "projects")
    }

    @Test func opensTheFolderHoldingASelectedFile() async {
        #expect(await browser(selecting: ["doc2"]).terminalFolder == "documents")
    }

    @Test func opensTheFolderShownForSeveralItems() async {
        let browser = await browser(at: "home", selecting: ["projects", "documents"])
        #expect(browser.terminalFolder == "home")
    }

    @Test func opensNothingInThisMac() async {
        #expect(await browser(at: .computer).terminalFolder == nil)
    }

    @Test func opensAVolumeSelectedInThisMac() async {
        #expect(await browser(at: .computer, selecting: ["usb"]).terminalFolder == "usb")
    }

    @Test func aContextMenuOnAFileOpensItsFolder() async throws {
        let browser = await browser(at: "home")
        let file = try await Fixture.standard.item(at: "doc2")
        #expect(browser.terminalFolder(for: [file]) == file.parentID)
    }
}
