import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// A cloud location stays where it is, named as it is, like the home folder,
/// which `ItemKindTests` covers by the same rule (ADR 0049).
@MainActor
@Suite struct BrowserStateCloudFolderTests {
    let fileSystem = ChangingFileSystem()

    /// A browser in This Mac, with iCloud Drive and optionally a volume selected.
    private func browser(selecting ids: Set<FileItem.ID> = ["icloud"]) async -> BrowserState {
        let browser = await makeBrowser(fileSystem: fileSystem, at: .computer)
        browser.setSelection(ids, in: browser.layout.focusedPane.activeTabID)
        return browser
    }

    /// The fixture's iCloud Drive inside a folder, as a cloud folder in the home
    /// folder is: the operations skip or refuse an item without a folder.
    private func cloudFolderInAFolder() async throws -> FileItem {
        var cloud = try await fileSystem.item(at: "icloud")
        cloud.parentID = "home"
        return cloud
    }

    @Test func refusesToRenameACloudFolder() async throws {
        let browser = await browser()
        let cloud = try await cloudFolderInAFolder()

        await browser.rename(cloud, to: "Other", undoManager: nil)

        #expect(try await fileSystem.item(at: "icloud").name == cloud.name)
    }

    @Test func refusesToTrashACloudFolder() async throws {
        let browser = await browser()

        await browser.moveSelectionToTrash(undoManager: nil)

        #expect(try await fileSystem.locations().contains { $0.id == "icloud" })
    }

    @Test func refusesToTrashASelectionWithACloudFolder() async throws {
        let browser = await browser(selecting: ["icloud", "usb"])

        await browser.moveSelectionToTrash(undoManager: nil)

        let locations = try await fileSystem.locations().map(\.id)
        #expect(locations.contains("icloud") && locations.contains("usb"))
    }

    @Test func offersNoRenameTrashCutOrCopyForACloudFolder() async {
        let browser = await browser()

        #expect(!browser.canRenameSelection)
        #expect(!browser.canTrashSelection)
        #expect(!browser.canCutOrCopySelection)
    }

    @Test func offersRenameTrashCutAndCopyForAPlainFolder() async {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")
        browser.setSelection(["doc2"], in: browser.layout.focusedPane.activeTabID)

        #expect(browser.canRenameSelection)
        #expect(browser.canTrashSelection)
        #expect(browser.canCutOrCopySelection)
    }

    @Test func doesNotCutOrCopyACloudFolder() async {
        let browser = await browser()

        browser.cutSelection()
        #expect(browser.clipboard == nil)

        browser.copySelection()
        #expect(browser.clipboard == nil)
    }

    @Test func doesNotPasteACloudFolderFromThePasteboard() async throws {
        let cloud = try await cloudFolderInAFolder()
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")

        await browser.pasteItems([cloud], resolver: ScriptedResolver(), undoManager: nil)

        #expect(!browser.focusedNames.contains(cloud.name))
    }
}
