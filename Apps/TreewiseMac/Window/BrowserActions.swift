import AppKit
import SwiftUI
import TreewiseCore
import TreewiseUI

/// What the menu bar and the toolbar can ask of a browser window (ADR 0022,
/// ADR 0081).
@MainActor
struct BrowserActions {
    let browser: BrowserState
    let undoManager: UndoManager?
    /// Whether the window shows a sheet: it then takes no new tab and is not
    /// moved beside another, until the sheet is answered.
    let showsSheet: Bool
    /// Puts the keyboard focus in the window's search field.
    let focusSearch: () -> Void
    /// Turns the address bar into a field to type a path in.
    let editAddress: () -> Void

    var hasSelection: Bool { !browser.selectedItems.isEmpty }
    var canRename: Bool { browser.canRenameSelection }
    var canTrash: Bool { browser.canTrashSelection }
    /// Whether the window can take a new tab or be put beside another.
    var canArrange: Bool { !showsSheet }
    var canMoveHere: Bool { browser.clipboard != nil && browser.canAddItems }
    var canAddItems: Bool { browser.canAddItems }
    /// The selected volumes that can be ejected; File > Eject ejects them (ADR 0044).
    var ejectableSelection: [FileItem] {
        let selection = browser.selectedItems
        return !selection.isEmpty && selection.allSatisfy(\.isEjectable) ? selection : []
    }
    func eject() { VolumeEjection.eject(ejectableSelection) }
    /// Whether there is a selection and another window to copy or move it to.
    var canSendToOtherWindow: Bool {
        hasSelection && WindowTabs.shared.otherWindow(than: NSApp.keyWindow) != nil
    }

    /// Whether the selection can also leave where it is: out of an archive it can only copy.
    var canMoveToOtherWindow: Bool { canSendToOtherWindow && browser.canCutSelection }

    func newFolder() { Task { await browser.newFolder(undoManager: undoManager) } }
    /// Whether names can be suggested for the selection or the folder (ADR 0057).
    var canSuggestNames: Bool { browser.canSuggestNames }
    func suggestNames() { NameReviewWindow.show(for: browser, undoManager: undoManager) }
    func suggestNamesForFolder() {
        NameReviewWindow.showWholeFolder(of: browser, undoManager: undoManager)
    }
    var canExtract: Bool { browser.canExtractSelection }
    var canCompress: Bool { browser.canCompressSelection }
    /// Extracting and compressing the selection (ADR 0074).
    var archives: ArchiveCommands { ArchiveCommands(browser: browser, undoManager: undoManager) }
    func moveToTrash() {
        Task { await browser.moveSelectionToTrash(undoManager: undoManager) }
    }
    func rename() { browser.renameRequest = browser.selectedItems.first?.id }
    /// Whether one file is selected that proposals can be asked for (ADR 0066).
    var canRenameWithSuggestions: Bool {
        let selected = browser.selectedItems
        return selected.count == 1 && browser.canSuggestName(for: selected[0])
    }
    func renameWithSuggestions() {
        browser.renameSuggests = true
        browser.renameRequest = browser.selectedItems.first?.id
    }
    /// Whether a terminal can open for the selection (ADR 0052).
    var canOpenTerminal: Bool { TerminalOpener.isAvailable && browser.terminalFolder != nil }
    func openTerminal() { TerminalOpener.open(browser.terminalFolder, settings: browser.settings) }

    /// Opens a window tab on the current folder (ADR 0037).
    func newTab() {
        WindowTabs.shared.openTab(
            at: browser.layout.focusedPane.activeTab.folder, beside: NSApp.keyWindow)
    }

    /// Opens a window on the current folder beside this one (ADR 0037).
    func windowBeside() {
        let folder = browser.layout.focusedPane.activeTab.folder
        WindowTabs.shared.openBeside(folder, from: NSApp.keyWindow)
    }

    /// Puts this window and the other window side by side.
    func tileWithOtherWindow() {
        let window = NSApp.keyWindow
        guard let other = WindowTabs.shared.otherWindow(than: window) else { return }
        WindowTabs.shared.tile(window, beside: other)
    }

    func show(_ viewMode: ViewMode) { browser.viewMode = viewMode }

    var showsDetails: Bool { browser.settings.showsDetails }
    func toggleDetails() { browser.settings.showsDetails.toggle() }

    /// Opens the selection: ⌘↓, or ⌥⌘↓ for the window the setting does not choose.
    func openSelection(option: Bool) {
        let placement = OpenPlacement.forOpening(
            command: false, option: option, preferred: browser.settings.doubleClickOpensIn)
        let pane = browser.layout.focusedPaneIndex
        let items = browser.selectedItems
        Task { await ItemOpening.open(items, from: pane, in: placement, browser: browser) }
    }

    /// Copy to Other Window or Move to Other Window (ADR 0037).
    func sendToOtherWindow(_ mode: TransferMode) {
        let window = NSApp.keyWindow
        Task {
            await WindowTabs.shared.send(
                selectionOf: browser, mode: mode, from: window, undoManager: undoManager)
        }
    }

    func moveHere() {
        Task { await browser.moveHere(resolver: AlertConflictResolver(), undoManager: undoManager) }
    }
}
