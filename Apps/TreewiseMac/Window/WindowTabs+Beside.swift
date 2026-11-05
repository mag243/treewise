import AppKit
import TreewiseCore
import TreewiseUI

/// Two windows side by side in place of split view (ADR 0037).
extension WindowTabs {
    /// The most recently active browser window other than `window` and its
    /// tabs: the one Open in Other Window, ⌥-double-click and Copy and Move to
    /// Other Window go to.
    func otherWindow(than window: NSWindow?) -> NSWindow? {
        let own = window?.tabbedWindows ?? window.map { [$0] } ?? []
        return NSApp.orderedWindows.first { candidate in
            candidate.isVisible && !own.contains { $0 === candidate }
                && browser(of: candidate) != nil
        }
    }

    /// The folder the other window shows, for Copy and Move to Other Window.
    func otherWindowFolder(than window: NSWindow?) -> FileItem.ID? {
        otherWindow(than: window).flatMap(browser(of:))?.layout.focusedPane.activeTab.folder
    }

    /// Copies or moves the selection of `browser` into the other window's
    /// folder; nothing happens without another window.
    func send(
        selectionOf browser: BrowserState, mode: TransferMode, from window: NSWindow?,
        undoManager: UndoManager?
    ) async {
        guard let folder = otherWindowFolder(than: window) else { return }
        await browser.send(
            selectionTo: folder, mode: mode, resolver: AlertConflictResolver(),
            undoManager: undoManager)
    }

    /// Shows `folder` in the other window, just behind `window`, or in a new
    /// window beside it when there is no other window.
    func openInOtherWindow(_ folder: FileItem.ID, from window: NSWindow?) async {
        guard let other = otherWindow(than: window), let browser = browser(of: other) else {
            await openBeside(folder, from: window)
            return
        }
        if let window { other.order(.below, relativeTo: window.windowNumber) }
        await browser.navigate(pane: browser.layout.focusedPaneIndex, to: folder)
    }

    /// Opens a window on `folder` and puts `window` and the new one on the left
    /// and right halves of the screen: Window Beside (⌥⌘N).
    func openBeside(_ folder: FileItem.ID, from window: NSWindow?) async {
        // A window with a sheet is not moved until the sheet is answered.
        guard window?.attachedSheet == nil else { return }
        guard let opened = await open(TabRequest(folder: folder)) else { return }
        // With "Prefer tabs: Always" in System Settings the window opens as a tab.
        if (opened.tabbedWindows?.count ?? 1) > 1 { opened.moveTabToNewWindow(nil) }
        tile(window, beside: opened)
        opened.makeKeyAndOrderFront(nil)
    }

    /// Puts `window` on the left half of its screen and `other` on the right,
    /// or against the edges when a screen is too narrow for two halves:
    /// Window > Tile Windows Side by Side, and the end of Window Beside.
    func tile(_ window: NSWindow?, beside other: NSWindow) {
        guard let screen = window?.screen ?? other.screen ?? NSScreen.main else { return }
        let (left, right) = SideBySide.frames(
            in: screen.visibleFrame, minimumWidth: WindowWidths.windowMinimum)
        window?.setFrame(left, display: true, animate: true)
        other.setFrame(right, display: true, animate: true)
    }
}
