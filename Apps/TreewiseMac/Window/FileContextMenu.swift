import AppKit
import TreewiseCore
import TreewiseUI

/// The context menu of a pane's list and icon view (PLAN.md M4, ADR 0142): for the selected
/// items, or for the folder when the click was on empty space. It shows what applies to what
/// was clicked, greys what applies but is refused there, and gives each specialised subject
/// one line, a submenu whose usual command comes first.
@MainActor
struct FileContextMenu {
    let browser: BrowserState
    let paneIndex: Int
    let undoManager: UndoManager?
    /// The pane's clipboard commands, shared with the Edit menu.
    let cut: () -> Void
    let copy: () -> Void
    let paste: () -> Void
    let canPaste: () -> Bool

    /// The menu for `items`, the selection the click was on, or for the
    /// pane's folder when `items` is empty.
    func menu(for items: [FileItem]) -> NSMenu {
        browser.focusPane(paneIndex)
        let menu = NSMenu()
        menu.autoenablesItems = false
        if items.isEmpty {
            addEmptySpaceItems(to: menu)
        } else {
            addItems(for: items, to: menu)
        }
        return menu
    }

    private func addItems(for items: [FileItem], to menu: NSMenu) {
        let groups: [[NSMenuItem]] = [
            openItems(for: items),
            renameAndTrashItems(for: items),
            clipboardItems(for: items) + moveToItems() + otherWindowItems(),
            subjectItems(for: items),
            [favoriteItem(for: items), terminalItem(for: items), showInFinderItem(for: items)]
                .compactMap(\.self),
        ]
        add(groups, to: menu)
    }

    /// New Folder, Folder Structure ▸ and Paste, for the folder shown.
    private func addEmptySpaceItems(to menu: NSMenu) {
        let canAdd = browser.canAddItems
        let groups: [[NSMenuItem]] = [
            [
                item("New Folder", symbol: "folder.badge.plus", enabled: canAdd) {
                    await browser.newFolder(undoManager: undoManager)
                },
                folderStructureMenu(in: browser.layout.focusedPane.activeTab.folder),
            ].compactMap(\.self),
            clipboardItems(for: []),
            [
                suggestNamesForFolderItem(title: "Suggest Names…"),
                terminalItem(for: []),
                showInFinderItem(for: []),
            ],
        ]
        add(groups, to: menu)
    }

    /// The groups with a line between them, an empty group leaving no line.
    private func add(_ groups: [[NSMenuItem]], to menu: NSMenu) {
        for group in groups where !group.isEmpty {
            if !menu.items.isEmpty { menu.addItem(.separator()) }
            for item in group { menu.addItem(item) }
        }
    }

    private func openItems(for items: [FileItem]) -> [NSMenuItem] {
        var shown = [open("Open", symbol: "arrow.up.forward.square", items, in: .samePane)]
        if items.count == 1, browser.placeToOpen(for: items[0]) != nil {
            shown.append(
                open("Open in New Tab", symbol: "plus.square.on.square", items, in: .newTab))
            shown.append(
                open("Open on Other Side", symbol: "rectangle.split.2x1", items, in: .otherPane))
        }
        if items.allSatisfy(\.isEjectable) {
            shown.append(
                ClosureMenuItem(String(localized: "Eject"), symbol: "eject") {
                    VolumeEjection.eject(items)
                })
        }
        return shown
    }

    /// Rename and its variants that apply, and Move to Trash; greyed where the items cannot
    /// change.
    private func renameAndTrashItems(for items: [FileItem]) -> [NSMenuItem] {
        let changeable = items.allSatisfy(\.canBeRenamedOrTrashed)
        var shown: [NSMenuItem] = []
        if items.count == 1 {
            shown.append(
                ClosureMenuItem(String(localized: "Rename"), symbol: "pencil", enabled: changeable)
                {
                    browser.renameRequest = items.first?.id
                })
            // Renaming with the add-ons' proposals at once, for one file (ADR 0066).
            if !items[0].isContainer, browser.canSuggestNames {
                shown.append(
                    ClosureMenuItem(
                        String(localized: "Rename with Suggestions"), symbol: "text.badge.star",
                        enabled: browser.canSuggestName(for: items[0])
                    ) {
                        browser.renameSuggests = true
                        browser.renameRequest = items.first?.id
                    })
            }
            // The same folder in every year's folder, as one step (ADR 0139).
            if let inAllYears = RenameInAllYearsSheet.menuItem(
                for: items[0], browser: browser, undoManager: undoManager, enabled: changeable)
            {
                shown.append(inAllYears)
            }
        }
        shown.append(
            item("Move to Trash", symbol: "trash", enabled: changeable) {
                await browser.moveSelectionToTrash(undoManager: undoManager)
            })
        return shown
    }

    /// Cut and Copy for a selection, and Paste and Move Item Here while there is something
    /// to paste.
    private func clipboardItems(for items: [FileItem]) -> [NSMenuItem] {
        var shown: [NSMenuItem] = []
        if !items.isEmpty {
            shown.append(
                ClosureMenuItem(
                    String(localized: "Cut"), symbol: "scissors",
                    enabled: items.allSatisfy(\.isMovable), handler: cut))
            shown.append(
                ClosureMenuItem(
                    String(localized: "Copy"), symbol: "doc.on.doc",
                    enabled: items.allSatisfy(\.isCopyable), handler: copy))
        }
        if canPaste() {
            shown.append(
                ClosureMenuItem(
                    String(localized: "Paste"), symbol: "doc.on.clipboard",
                    enabled: browser.canAddItems, handler: paste))
        }
        if browser.clipboard != nil {
            shown.append(
                ClosureMenuItem(
                    String(localized: "Move Item Here"), symbol: "arrow.right.doc.on.clipboard",
                    enabled: browser.canAddItems
                ) {
                    Task {
                        await browser.moveHere(
                            resolver: AlertConflictResolver.make(), undoManager: undoManager)
                    }
                })
        }
        return shown
    }

    /// Move to ▸ and Copy to ▸, for the items the menu is about (ADR 0147).
    private func moveToItems() -> [NSMenuItem] {
        [
            MoveToMenu.item(.move, browser: browser, undoManager: undoManager),
            MoveToMenu.item(.copy, browser: browser, undoManager: undoManager),
        ]
    }

    /// Copy and Move to Other Side, while there is another half or window (ADR 0154).
    private func otherWindowItems() -> [NSMenuItem] {
        let window = NSApp.keyWindow
        guard AppServices.windows.hasOtherSide(of: browser, from: window) else { return [] }
        return [
            ClosureMenuItem(String(localized: "Copy to Other Side"), symbol: "doc.on.doc.fill") {
                send(.copy, from: window)
            },
            ClosureMenuItem(
                String(localized: "Move to Other Side"), symbol: "arrow.right.square",
                enabled: browser.canCutSelection
            ) {
                send(.move, from: window)
            },
        ]
    }

    private func send(_ mode: TransferMode, from window: NSWindow?) {
        Task {
            await AppServices.windows.sendToOtherSide(
                selectionOf: browser, mode: mode, from: window, undoManager: undoManager)
        }
    }

    /// Open in Terminal, for the folder of `items` (ADR 0052).
    private func terminalItem(for items: [FileItem]) -> NSMenuItem {
        let folder = browser.terminalFolder(for: items)
        let settings = browser.settings
        return ClosureMenuItem(
            String(localized: "Open in Terminal"), symbol: "terminal",
            enabled: TerminalOpener.isAvailable && folder != nil
        ) {
            TerminalOpener.open(folder, settings: settings)
        }
    }

    private func showInFinderItem(for items: [FileItem]) -> NSMenuItem {
        let shown = items.isEmpty ? browser.layout.focusedPane.activeTab.folder : nil
        return ClosureMenuItem(String(localized: "Show in Finder"), symbol: "folder") {
            let ids = items.isEmpty ? shown.map { [$0] } ?? [] : items.map(\.id)
            NSWorkspace.shared.activateFileViewerSelecting(ids.map(\.urlShownInFinder))
        }
    }

    /// Add to or Remove from Favorites, for one folder (ADR 0050).
    private func favoriteItem(for items: [FileItem]) -> NSMenuItem? {
        guard let folder = items.first, items.count == 1, folder.isContainer,
            !folder.id.isInsideArchive
        else { return nil }
        return browser.isFavorite(folder.id)
            ? item("Remove from Favorites", symbol: "star.slash") {
                await browser.removeFavorite(folder.id)
            }
            : item("Add to Favorites", symbol: "star") {
                await browser.addFavorite(folder.id)
            }
    }

    private func open(
        _ title: String.LocalizationValue, symbol: String, _ items: [FileItem],
        in placement: OpenPlacement
    ) -> NSMenuItem {
        ClosureMenuItem(String(localized: title), symbol: symbol) {
            Task {
                await ItemOpening.open(items, from: paneIndex, in: placement, browser: browser)
            }
        }
    }

    func item(
        _ title: String.LocalizationValue, symbol: String, enabled: Bool = true,
        _ action: @escaping () async -> Void
    ) -> NSMenuItem {
        ClosureMenuItem(String(localized: title), symbol: symbol, enabled: enabled) {
            Task { await action() }
        }
    }
}
