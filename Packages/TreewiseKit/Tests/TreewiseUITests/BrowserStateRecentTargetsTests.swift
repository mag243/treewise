import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// The folders items were last moved or copied into, by any way, for Move to and Copy to
/// (ADR 0147), kept in the device's settings.
@MainActor
@Suite struct BrowserStateRecentTargetsTests {
    let fileSystem = ChangingFileSystem()

    private func browser(
        settings: BrowserSettings = BrowserSettings(store: MemorySettingsStore())
    ) async -> BrowserState {
        await makeBrowser(fileSystem: fileSystem, at: "documents", settings: settings)
    }

    private func tab(_ browser: BrowserState) -> TabModel.ID {
        browser.layout.focusedPane.activeTabID
    }

    @Test func aPasteElsewhereMakesItsFolderARecentTarget() async {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        browser.copySelection()
        await browser.navigate(pane: 0, to: "projects")

        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(browser.settings.recentTargets.folders == ["projects"])
        #expect(await browser.recentTargets().map(\.id) == ["projects"])
    }

    @Test func aDropMakesItsFolderARecentTarget() async throws {
        let browser = await browser()
        let notes = try await fileSystem.item(at: "doc2")
        let projects = try await fileSystem.item(at: "projects")

        await browser.drop(
            [notes], onto: projects, modifiers: [], resolver: ScriptedResolver(),
            undoManager: nil)

        #expect(browser.settings.recentTargets.folders == ["projects"])
    }

    @Test func aCopyBesideItselfIsNoRecentTarget() async {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        browser.copySelection()

        await browser.paste(resolver: ScriptedResolver(.keepBoth), undoManager: nil)

        #expect(browser.focusedNames.contains("Notes copy.md"), "the copy was made")
        #expect(browser.settings.recentTargets.folders.isEmpty)
    }

    @Test func aFolderThatIsGoneIsLeftOut() async throws {
        let settings = BrowserSettings(store: MemorySettingsStore())
        settings.recentTargets = RecentTargets(folders: ["gone", "projects"])
        let browser = await browser(settings: settings)

        #expect(await browser.recentTargets().map(\.id) == ["projects"])
    }

    @Test func theRecentTargetsAreKeptForTheNextStart() {
        let store = MemorySettingsStore()
        BrowserSettings(store: store).recentTargets = RecentTargets(folders: ["projects", "a"])

        #expect(BrowserSettings(store: store).recentTargets.folders == ["projects", "a"])
    }
}
