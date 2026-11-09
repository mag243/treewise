import AppKit
import SwiftUI
import TreewiseCore
import TreewiseUI

/// What the menu bar can ask of the window in front (ADR 0022).
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
        let window = NSApp.keyWindow
        Task { await WindowTabs.shared.openBeside(folder, from: window) }
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

extension FocusedValues {
    /// The actions of the browser window in front.
    @Entry var browserActions: BrowserActions?
}

/// The menu bar's commands and their keys, as the README's table lists them
/// (ADR 0022). Cut, Copy, Paste and Undo come from the standard Edit menu
/// through the responder chain; Close and Show Next and Previous Tab from
/// macOS's window tabs (ADR 0037).
struct BrowserCommands: Commands {
    /// The download page (ADR 0053), in place of a Help book Treewise does not have.
    private static let website = URL(string: "https://treewise.m-domain.me/")

    @FocusedValue(\.browserActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") { actions?.newTab() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(!(actions?.canArrange ?? false))
            Divider()
            Button("New Folder") { actions?.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!(actions?.canAddItems ?? false))
            Button("Open") { actions?.openSelection(option: false) }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(!(actions?.hasSelection ?? false))
            Button("Open in Other Window") { actions?.openSelection(option: true) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(!(actions?.hasSelection ?? false))
            Button("Suggest Names…") { actions?.suggestNames() }
                .disabled(!(actions?.canSuggestNames ?? false))
            Button("Suggest Names for Whole Folder…") { actions?.suggestNamesForFolder() }
                .disabled(!(actions?.canSuggestNames ?? false))
            Button("Extract All…") { actions?.archives.extract() }
                .disabled(!(actions?.canExtract ?? false))
            Button("Compress to ZIP") { actions?.archives.compress(to: .zip) }
                .disabled(!(actions?.canCompress ?? false))
            Menu("Compress to") {
                Button("7z File") { actions?.archives.compress(to: .sevenZip) }
                Button("TAR.GZ File") { actions?.archives.compress(to: .tarGzip) }
            }
            .disabled(!(actions?.canCompress ?? false))
            Button("Rename") { actions?.rename() }
                .disabled(!(actions?.canRename ?? false))
            Button("Rename with Suggestions") { actions?.renameWithSuggestions() }
                .disabled(!(actions?.canRenameWithSuggestions ?? false))
            Button("Eject") { actions?.eject() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(actions?.ejectableSelection.isEmpty ?? true)
            Button("Open in Terminal") { actions?.openTerminal() }
                .keyboardShortcut("t", modifiers: [.command, .control])
                .disabled(!(actions?.canOpenTerminal ?? false))
            Divider()
            Button("Go to Address") { actions?.editAddress() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(actions == nil)
        }
        CommandGroup(after: .pasteboard) {
            Button("Move Item Here") { actions?.moveHere() }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(!(actions?.canMoveHere ?? false))
            Button("Move to Trash") { actions?.moveToTrash() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!(actions?.canTrash ?? false))
            Divider()
            Button("Copy to Other Window") { actions?.sendToOtherWindow(.copy) }
                .disabled(!(actions?.canSendToOtherWindow ?? false))
            Button("Move to Other Window") { actions?.sendToOtherWindow(.move) }
                .disabled(!(actions?.canMoveToOtherWindow ?? false))
            Divider()
            Button("Find") { actions?.focusSearch() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)
        }
        CommandGroup(before: .toolbar) {
            Button("as Icons") { actions?.show(.icons) }
                .keyboardShortcut("1", modifiers: .command)
            Button("as List") { actions?.show(.list) }
                .keyboardShortcut("2", modifiers: .command)
            Divider()
            Button(actions?.showsDetails == true ? "Hide Details" : "Show Details") {
                actions?.toggleDetails()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(actions == nil)
            Divider()
        }
        CommandGroup(before: .windowArrangement) {
            Button("Window Beside") { actions?.windowBeside() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(!(actions?.canArrange ?? false))
            Button("Tile Windows Side by Side") { actions?.tileWithOtherWindow() }
                .disabled(!(actions?.canArrange ?? false))
            Divider()
        }
        CommandGroup(replacing: .help) {
            Button("Treewise Website") {
                if let url = Self.website { NSWorkspace.shared.open(url) }
            }
        }
    }
}
