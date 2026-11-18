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
    let undoManager: UndoManager
    /// Opens a folder, or shows a file in Quick Look.
    let open: (FileItem) -> Void
    /// Opens the name overview of the selection, or of the folder's files (ADR 0129).
    let suggestNames: (_ wholeFolder: Bool) -> Void
    /// Asks for a name in the folder view's sheet (ADR 0130).
    let askName: (NameSheetRequest) -> Void
    /// Asks for the folder to move or copy items to, where the width is compact and no
    /// second folder shows (ADR 0132); `nil` elsewhere.
    var moveTo: ((MoveToRequest) -> Void)?
    /// Offers items to the system's share sheet, in the same layout (ADR 0132); `nil`
    /// elsewhere.
    var share: (([FileItem]) -> Void)?

    /// Whether names can be proposed for what the folder shows.
    var canSuggestNames: Bool {
        browser.canSuggestNames
    }

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

    /// Opens the name overview of `items`, which become the selection.
    func suggestNames(for items: [FileItem]) {
        select(items)
        suggestNames(false)
    }

    /// Asks for a new name; with `suggests`, with the add-ons' proposals asked at once.
    func rename(_ item: FileItem, suggests: Bool = false) {
        askName(NameSheetRequest(purpose: .rename(item), name: item.name, suggests: suggests))
    }

    /// Whether the add-ons can propose a name for `item` while it is renamed.
    func canSuggestName(for item: FileItem) -> Bool {
        browser.canSuggestName(for: item)
    }

    /// Asks for the new folder's name, "untitled folder" filled in; Create makes it and
    /// Cancel makes nothing (ADR 0130).
    func newFolder() {
        Task {
            guard let name = await browser.proposedNewFolderName() else { return }
            askName(NameSheetRequest(purpose: .newFolder, name: name))
        }
    }

    func isFavorite(_ folder: FileItem) -> Bool {
        browser.isFavorite(folder.id)
    }

    func addFavorite(_ folder: FileItem) {
        Task { await browser.addFavorite(folder.id) }
    }

    func removeFavorite(_ folder: FileItem) {
        Task { await browser.removeFavorite(folder.id) }
    }

    /// The menu acts on the items it was opened for, which become the selection.
    private func select(_ items: [FileItem]) {
        browser.setSelection(Set(items.map(\.id)), in: browser.layout.focusedPane.activeTabID)
    }
}
