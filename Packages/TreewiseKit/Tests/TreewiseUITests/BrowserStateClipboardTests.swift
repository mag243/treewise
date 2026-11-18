import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Emptying the clipboard without pasting, as the iPhone's paste bar does (ADR 0132).
@MainActor
@Suite struct BrowserStateClipboardTests {
    @Test func emptyingTheClipboardShowsCutItemsUndimmedInEveryWindow() async {
        let clipboard = SharedClipboard()
        let left = BrowserState(
            fileSystem: Fixture.standard, watcher: ManualFolderWatcher(),
            startFolder: "documents", clipboard: clipboard)
        let right = BrowserState(
            fileSystem: Fixture.standard, watcher: ManualFolderWatcher(),
            startFolder: "projects", clipboard: clipboard)
        await left.start()
        await right.start()
        left.setSelection(["doc2"], in: left.layout.focusedPane.activeTabID)
        left.cutSelection()

        right.emptyClipboard()

        #expect(left.clipboard == nil)
        #expect(left.clipboard?.isCut("doc2") != true, "shown undimmed")
    }
}
