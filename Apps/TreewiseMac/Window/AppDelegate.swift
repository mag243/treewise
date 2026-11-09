import AppKit
import OSLog
import TreewiseFileSystem

/// Runs the offer to move to Applications once launching is done, before
/// anyone starts working in a window, saves the windows when Treewise quits
/// (ADR 0038), and opens tabs from the tab bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if let appearance = LaunchOptions.appearance { NSApp.appearance = appearance }
            ApplicationsMover.offerIfNeeded()
            FolderSettingsCleaner.start(with: NameReviewWindow.store)
            FileOperationRunner.removeLeftoverArchiveCopies(in: LaunchOptions.locations)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            WindowSession.saveForQuitting()
            ArchiveEntryDrag.releasePromises()
        }
        return .terminateNow
    }

    /// The tab bar's + button: AppKit shows it when the responder chain,
    /// which ends at the application's delegate, answers this.
    @MainActor @objc func newWindowForTab(_ sender: Any?) {
        Logger(subsystem: "me.m-domain.treewise", category: "tabs").info("The + button")
        WindowTabs.shared.openTab(besideWindowOf: NSApp.keyWindow)
    }
}
