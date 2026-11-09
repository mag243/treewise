import AppKit
import TreewiseCore
import TreewiseUI

/// A menu item that runs a closure, so a menu can be built from the pane's actions.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    /// `symbol` is the SF Symbol beside the title, the same one the command
    /// bar uses for that action.
    init(_ title: String, symbol: String, enabled: Bool = true, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        // macOS 27 hides a menu item's image unless asked; CI's older Xcode
        // does not know the property (ADR 0012, ADR 0052).
        #if compiler(>=6.4)
            if #available(macOS 27, *) { preferredImageVisibility = .visible }
        #endif
        target = self
        isEnabled = enabled
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("ClosureMenuItem is made in code only")
    }

    @objc private func run() {
        handler()
    }
}

/// The context menu of a pane's list and, later, its icon view (PLAN.md M4):
/// for the selected items, or for the folder when the click was on empty space.
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
            menu.addItem(
                item("New Folder", symbol: "folder.badge.plus", enabled: browser.canAddItems) {
                    await browser.newFolder(undoManager: undoManager)
                })
        } else {
            addOpenItems(for: items, to: menu)
            if items.allSatisfy(\.isEjectable) {
                menu.addItem(
                    ClosureMenuItem(String(localized: "Eject"), symbol: "eject") {
                        VolumeEjection.eject(items)
                    })
            }
            menu.addItem(.separator())
            addFavoriteItem(for: items, to: menu)
            addRenameAndTrashItems(for: items, to: menu)
        }
        menu.addItem(.separator())
        addClipboardItems(for: items, to: menu)
        if !items.isEmpty { addOtherWindowItems(to: menu) }
        if !items.isEmpty { addArchiveItems(to: menu) }
        menu.addItem(.separator())
        menu.addItem(terminalItem(for: items))
        menu.addItem(suggestNamesItem())
        if !items.isEmpty { menu.addItem(suggestNamesForFolderItem()) }
        let shown = items.isEmpty ? browser.layout.focusedPane.activeTab.folder : nil
        menu.addItem(
            ClosureMenuItem(String(localized: "Show in Finder"), symbol: "folder") {
                let ids = items.isEmpty ? shown.map { [$0] } ?? [] : items.map(\.id)
                NSWorkspace.shared.activateFileViewerSelecting(ids.map(\.urlShownInFinder))
            })
        return menu
    }

    private func addOpenItems(for items: [FileItem], to menu: NSMenu) {
        let folder = items.count == 1 && items[0].isContainer
        menu.addItem(open("Open", symbol: "arrow.up.forward.square", items, in: .samePane))
        menu.addItem(
            open(
                "Open in New Tab", symbol: "plus.square.on.square", items, in: .newTab,
                enabled: folder))
        menu.addItem(
            open(
                "Open in Other Window", symbol: "rectangle.split.2x1", items, in: .otherPane,
                enabled: folder))
    }

    /// Copy and Move to Other Window, for the selection the click was on (ADR 0037).
    private func addOtherWindowItems(to menu: NSMenu) {
        let window = NSApp.keyWindow
        let hasOther = WindowTabs.shared.otherWindow(than: window) != nil
        menu.addItem(
            ClosureMenuItem(
                String(localized: "Copy to Other Window"), symbol: "doc.on.doc.fill",
                enabled: hasOther
            ) {
                send(.copy, from: window)
            })
        menu.addItem(
            ClosureMenuItem(
                String(localized: "Move to Other Window"), symbol: "arrow.right.square",
                enabled: hasOther
            ) {
                send(.move, from: window)
            })
    }

    private func send(_ mode: TransferMode, from window: NSWindow?) {
        Task {
            await WindowTabs.shared.send(
                selectionOf: browser, mode: mode, from: window, undoManager: undoManager)
        }
    }

    /// Extract All, for an archive, and the ways to compress the selection (ADR 0074).
    private func addArchiveItems(to menu: NSMenu) {
        let commands = ArchiveCommands(browser: browser, undoManager: undoManager)
        let canCompress = browser.canCompressSelection
        menu.addItem(.separator())
        if browser.canExtractSelection {
            menu.addItem(
                ClosureMenuItem(String(localized: "Extract All…"), symbol: "arrow.up.bin") {
                    commands.extract()
                })
        }
        menu.addItem(
            ClosureMenuItem(
                String(localized: "Compress to ZIP"), symbol: "archivebox", enabled: canCompress
            ) {
                commands.compress(to: .zip)
            })
        let others = NSMenu()
        others.addItem(
            ClosureMenuItem(String(localized: "7z File"), symbol: "archivebox") {
                commands.compress(to: .sevenZip)
            })
        others.addItem(
            ClosureMenuItem(String(localized: "TAR.GZ File"), symbol: "archivebox") {
                commands.compress(to: .tarGzip)
            })
        let compressTo = NSMenuItem(
            title: String(localized: "Compress to"), action: nil, keyEquivalent: "")
        compressTo.image = NSImage(systemSymbolName: "archivebox", accessibilityDescription: nil)
        compressTo.isEnabled = canCompress
        compressTo.submenu = others
        menu.addItem(compressTo)
    }

    /// Suggest Names, for the selection or the folder (ADR 0057).
    private func suggestNamesItem() -> NSMenuItem {
        ClosureMenuItem(
            String(localized: "Suggest Names…"), symbol: "text.badge.star",
            enabled: browser.canSuggestNames
        ) { [browser, undoManager] in
            NameReviewWindow.show(for: browser, undoManager: undoManager)
        }
    }

    /// Suggest Names for the whole folder, for a click on an item, which selects it.
    private func suggestNamesForFolderItem() -> NSMenuItem {
        ClosureMenuItem(
            String(localized: "Suggest Names for Whole Folder…"), symbol: "text.badge.star",
            enabled: browser.canSuggestNames
        ) { [browser, undoManager] in
            NameReviewWindow.showWholeFolder(of: browser, undoManager: undoManager)
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

    /// Add to or Remove from Favorites, for one folder (ADR 0050).
    private func addFavoriteItem(for items: [FileItem], to menu: NSMenu) {
        guard let folder = items.first, items.count == 1, folder.isContainer else { return }
        menu.addItem(
            browser.isFavorite(folder.id)
                ? item("Remove from Favorites", symbol: "star.slash") {
                    await browser.removeFavorite(folder.id)
                }
                : item("Add to Favorites", symbol: "star") {
                    await browser.addFavorite(folder.id)
                })
    }

    private func addRenameAndTrashItems(for items: [FileItem], to menu: NSMenu) {
        let changeable = items.allSatisfy(\.canBeRenamedOrTrashed)
        menu.addItem(
            ClosureMenuItem(
                String(localized: "Rename"), symbol: "pencil",
                enabled: items.count == 1 && changeable
            ) {
                browser.renameRequest = items.first?.id
            })
        // Renaming with the add-ons' proposals at once, for one file (ADR 0066).
        menu.addItem(
            ClosureMenuItem(
                String(localized: "Rename with Suggestions"), symbol: "text.badge.star",
                enabled: items.count == 1 && changeable && browser.canSuggestName(for: items[0])
            ) {
                browser.renameSuggests = true
                browser.renameRequest = items.first?.id
            })
        menu.addItem(
            item("Move to Trash", symbol: "trash", enabled: changeable) {
                await browser.moveSelectionToTrash(undoManager: undoManager)
            })
    }

    private func addClipboardItems(for items: [FileItem], to menu: NSMenu) {
        if !items.isEmpty {
            let movable = items.allSatisfy(\.isMovable)
            menu.addItem(
                ClosureMenuItem(
                    String(localized: "Cut"), symbol: "scissors", enabled: movable, handler: cut))
            menu.addItem(
                ClosureMenuItem(
                    String(localized: "Copy"), symbol: "doc.on.doc", enabled: movable, handler: copy
                ))
        }
        menu.addItem(
            ClosureMenuItem(
                String(localized: "Paste"), symbol: "doc.on.clipboard",
                enabled: canPaste() && browser.canAddItems,
                handler: paste))
        menu.addItem(
            ClosureMenuItem(
                String(localized: "Move Item Here"), symbol: "arrow.right.doc.on.clipboard",
                enabled: browser.clipboard != nil && browser.canAddItems
            ) {
                Task {
                    await browser.moveHere(
                        resolver: AlertConflictResolver(), undoManager: undoManager)
                }
            })
    }

    private func open(
        _ title: String.LocalizationValue, symbol: String, _ items: [FileItem],
        in placement: OpenPlacement, enabled: Bool = true
    ) -> NSMenuItem {
        ClosureMenuItem(String(localized: title), symbol: symbol, enabled: enabled) {
            Task {
                await ItemOpening.open(items, from: paneIndex, in: placement, browser: browser)
            }
        }
    }

    private func item(
        _ title: String.LocalizationValue, symbol: String, enabled: Bool = true,
        _ action: @escaping () async -> Void
    ) -> NSMenuItem {
        ClosureMenuItem(String(localized: title), symbol: symbol, enabled: enabled) {
            Task { await action() }
        }
    }
}
