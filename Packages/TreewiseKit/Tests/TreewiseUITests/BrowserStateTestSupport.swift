import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// A browser on the standard fixture, started in Documents.
@MainActor
func makeBrowser(
    fileSystem: any FileSystemProviding = Fixture.standard,
    watcher: ManualFolderWatcher = ManualFolderWatcher(),
    at folder: FileItem.ID = "documents",
    settings: BrowserSettings = BrowserSettings(store: MemorySettingsStore())
) async -> BrowserState {
    let browser = BrowserState(
        fileSystem: fileSystem, watcher: watcher, startFolder: folder, settings: settings)
    await browser.start()
    return browser
}

extension BrowserState {
    /// The names of what the focused pane's active tab shows, in list order.
    var focusedNames: [String] {
        visibleItems(of: layout.focusedPane.activeTabID).map(\.name)
    }

    /// The folder the focused pane's active tab shows.
    var focusedFolder: FileItem.ID {
        layout.focusedPane.activeTab.folder
    }
}

/// Lets other tasks run until `condition` holds, without waiting on the clock.
/// Returns whether it held before the tasks had a thousand turns.
@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<1_000 where !condition() {
        await Task.yield()
    }
    return condition()
}
