import Foundation
import TreewiseCore
import TreewiseUI

/// What the folder view's menus and toolbar do with items: the shared
/// operations of `BrowserState` (ADR 0047), with the scene's undo and the
/// conflict question.
@MainActor
struct ItemActions {
    let browser: BrowserState
    let conflicts: ConflictQuestions
    let undoManager: UndoManager?
    /// Opens a folder, or shows a file in Quick Look.
    let open: (FileItem) -> Void

    /// Whether Paste has something to put in the folder shown.
    var canPaste: Bool {
        browser.clipboard != nil && browser.canAddItems
    }

    /// Whether the folder shown takes new items, such as a new folder.
    var canAddItems: Bool {
        browser.canAddItems
    }

    func cut(_ items: [FileItem]) {
        select(items)
        browser.cutSelection()
    }

    func copy(_ items: [FileItem]) {
        select(items)
        browser.copySelection()
    }

    func paste() {
        Task { await browser.paste(resolver: conflicts.resolver(), undoManager: undoManager) }
    }

    func moveToTrash(_ items: [FileItem]) {
        select(items)
        Task { await browser.moveSelectionToTrash(undoManager: undoManager) }
    }

    /// Asks for a new name; the folder view shows the question.
    func rename(_ item: FileItem) {
        browser.renameRequest = item.id
    }

    /// Creates "untitled folder" and asks for its name.
    func newFolder() {
        Task { await browser.newFolder(undoManager: undoManager) }
    }

    /// The menu acts on the items it was opened for, which become the selection.
    private func select(_ items: [FileItem]) {
        browser.setSelection(Set(items.map(\.id)), in: browser.layout.focusedPane.activeTabID)
    }
}
