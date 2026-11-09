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

/// The longest a test waits for a change on the real disk.
private let diskDeadline = Duration.seconds(30)
/// How long to wait before looking again at a change on the real disk.
private let diskPollInterval = Duration.milliseconds(10)

/// Waits until `condition` holds, for a test whose change really goes to the
/// disk: it passes through the serial queue of file operations, behind whatever
/// else is on it, so a number of turns says nothing about how far it got.
/// Returns as soon as it holds; the deadline only ends a test that fails.
@MainActor
func eventuallyOnDisk(_ condition: @MainActor () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: diskDeadline)
    while !condition() && clock.now < deadline {
        try? await Task.sleep(for: diskPollInterval)
    }
    return condition()
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
