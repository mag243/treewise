import AppKit
import TreewiseCore
import TreewiseUI

/// The other side of a window (ADR 0154): the other half of a split window, otherwise the
/// other window. Open on Other Side, ⌥-double-click and Copy and Move to Other Side go
/// there, as Core's `PaneLayout.otherSide` decides.
extension WindowTabs {
    /// Where the other side of `browser`'s window is, for opening or for sending.
    func otherSide(of browser: BrowserState, from window: NSWindow?, for use: OtherSide.Use)
        -> OtherSide?
    {
        browser.layout.otherSide(hasOtherWindow: otherWindow(than: window) != nil, for: use)
    }

    /// Whether the selection of `browser` has somewhere to be copied or moved to: another
    /// half or window, showing another folder.
    func hasOtherSide(of browser: BrowserState, from window: NSWindow?) -> Bool {
        sendingFolder(of: browser, from: window) != nil
    }

    /// The folder Copy and Move to Other Side go to; `nil` without another half or window,
    /// or when it shows the folder the selection is in, where a copy would only be named
    /// "copy" and a move would do nothing.
    private func sendingFolder(of browser: BrowserState, from window: NSWindow?) -> FileItem.ID? {
        let folder: FileItem.ID?
        switch otherSide(of: browser, from: window, for: .sending) {
        case .pane(let other):
            folder = browser.layout.pane(at: other)?.activeTab.folder
        case .otherWindow:
            folder = otherWindowFolder(than: window)
        case .newWindowBeside, nil:
            folder = nil
        }
        return folder == browser.layout.focusedPane.activeTab.folder ? nil : folder
    }

    /// Shows `folder` on the other side: in the other half, which the active half keeps
    /// the focus from; in the other window; or in a new window beside this one.
    func openOnOtherSide(_ folder: FileItem.ID, of browser: BrowserState, from window: NSWindow?)
        async
    {
        switch otherSide(of: browser, from: window, for: .opening) {
        case .pane(let other):
            let active = browser.layout.focusedPaneIndex
            await browser.navigate(pane: other, to: folder)
            browser.focusPane(active)
        case .otherWindow:
            await openInOtherWindow(folder, from: window)
        case .newWindowBeside:
            openBeside(folder, from: window)
        case nil:
            break
        }
    }

    /// Copies or moves the selection of `browser` into the folder of the other side;
    /// nothing happens without one.
    func sendToOtherSide(
        selectionOf browser: BrowserState, mode: TransferMode, from window: NSWindow?,
        undoManager: UndoManager?
    ) async {
        guard let folder = sendingFolder(of: browser, from: window) else { return }
        await browser.send(
            selectionTo: folder, mode: mode, resolver: AlertConflictResolver.make(),
            undoManager: undoManager)
    }
}
