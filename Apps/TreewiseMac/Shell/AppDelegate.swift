import AppKit
import OSLog
import TreewiseFileSystem

/// Builds the menu bar and opens the first window (ADR 0081), runs the offer
/// to move to Applications once launching is done, before anyone starts
/// working in a window, and saves the windows when Treewise quits (ADR 0038).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { MainMenu.install() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if let appearance = LaunchOptions.appearance { NSApp.appearance = appearance }
            WindowTabs.shared.openFirstWindow()
            ApplicationsMover.offerIfNeeded()
            FolderSettingsCleaner.start(with: NameReviewWindow.store)
            FileOperationRunner.removeLeftoverArchiveCopies(in: LaunchOptions.locations)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            WindowSession.saveForQuitting()
            ArchiveEntryDrag.releasePromises()
            FileOperationRunner.removeLeftoverArchiveCopies(in: LaunchOptions.locations)
        }
        return .terminateNow
    }

    /// Treewise keeps running without windows, as Finder does.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// A click on the Dock icon with no window open opens one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { MainActor.assumeIsolated { WindowTabs.shared.openWindow() } }
        return true
    }

    /// File > New Window (⌘N): a window at the start folder (ADR 0023).
    @MainActor @objc func newWindow(_ sender: Any?) {
        WindowTabs.shared.openWindow()
    }

    /// File > New Tab when no browser window is open, which opens one: AppKit
    /// asks the responder chain, which ends here. A browser window answers it
    /// itself, also while it shows a sheet, when it takes no tab.
    @MainActor @objc func newWindowForTab(_ sender: Any?) {
        guard NSApp.mainWindow.flatMap(WindowTabs.shared.browser(of:)) == nil else { return }
        Logger(subsystem: "me.m-domain.treewise", category: "tabs").info("New tab")
        WindowTabs.shared.openWindow()
    }

    /// Treewise > Settings… (⌘,).
    @MainActor @objc func showSettings(_ sender: Any?) {
        SettingsWindow.show()
    }
}
