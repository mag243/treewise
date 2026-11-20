import AppKit
import TreewiseCore
import TreewiseUI

/// The context menu's specialised subjects, one line each (ADR 0142): Extract All… for an
/// archive, Compress ▸, Folder Structure ▸ for a folder (ADR 0091, ADR 0099, ADR 0102) and
/// Suggest Names ▸ (ADR 0057), each submenu with its usual command first.
extension FileContextMenu {
    func subjectItems(for items: [FileItem]) -> [NSMenuItem] {
        var shown: [NSMenuItem] = []
        let commands = ArchiveCommands(browser: browser, undoManager: undoManager)
        if browser.canExtractSelection {
            shown.append(
                ClosureMenuItem(String(localized: "Extract All…"), symbol: "arrow.up.bin") {
                    commands.extract()
                })
        }
        shown.append(compressMenu(commands))
        if items.count == 1, items[0].kind == .folder, ArchivePath(items[0].id) == nil,
            let structure = folderStructureMenu(for: items[0])
        {
            shown.append(structure)
        }
        shown.append(suggestNamesMenu())
        return shown
    }

    /// Compress ▸ with ZIP first, then 7z and TAR.GZ (ADR 0074).
    private func compressMenu(_ commands: ArchiveCommands) -> NSMenuItem {
        let zip = ClosureMenuItem(String(localized: "ZIP File"), symbol: "archivebox") {
            commands.compress(to: .zip)
        }
        let menu = submenu(
            "Compress", symbol: "archivebox",
            [
                zip,
                ClosureMenuItem(String(localized: "7z File"), symbol: "archivebox") {
                    commands.compress(to: .sevenZip)
                },
                ClosureMenuItem(String(localized: "TAR.GZ File"), symbol: "archivebox") {
                    commands.compress(to: .tarGzip)
                },
            ])
        menu.isEnabled = browser.canCompressSelection
        return menu
    }

    /// Folder Structure ▸ on one folder: New Folders from Template ▸, Add Missing Folders…,
    /// Save as Template…, Copy Structure and, once one is copied, Paste Structure….
    private func folderStructureMenu(for folder: FileItem) -> NSMenuItem? {
        let save = FolderTemplateMenu.saveItem(for: folder, browser: browser)
        save?.title = String(localized: "Save as Template…")
        let copy = FolderTemplateMenu.copyItem(for: folder, browser: browser)
        copy?.title = String(localized: "Copy Structure")
        return structureMenu([
            FolderTemplateMenu.newFoldersItem(
                in: folder.id, browser: browser, undoManager: undoManager),
            FolderTemplateMenu.missingItem(
                for: folder.id, browser: browser, undoManager: undoManager),
            save, copy, pasteStructureItem(in: folder.id, enabled: true),
        ])
    }

    /// Folder Structure ▸ on empty space, for the folder shown: New Folders from Template ▸,
    /// Add Missing Folders… and, once one is copied, Paste Structure….
    func folderStructureMenu(in folder: FileItem.ID) -> NSMenuItem? {
        let canAdd = browser.canAddItems
        return structureMenu([
            FolderTemplateMenu.newFoldersItem(
                in: folder, browser: browser, undoManager: undoManager, enabled: canAdd),
            FolderTemplateMenu.missingItem(
                for: folder, browser: browser, undoManager: undoManager, enabled: canAdd),
            pasteStructureItem(in: folder, enabled: canAdd),
        ])
    }

    /// Paste Structure…, only while a structure is copied.
    private func pasteStructureItem(in folder: FileItem.ID, enabled: Bool) -> NSMenuItem? {
        guard FolderTemplatesService.copiedStructure != nil else { return nil }
        let paste = FolderTemplateMenu.pasteItem(
            in: folder, browser: browser, undoManager: undoManager, enabled: enabled)
        paste.title = String(localized: "Paste Structure…")
        return paste
    }

    private func structureMenu(_ items: [NSMenuItem?]) -> NSMenuItem? {
        let shown = items.compactMap(\.self)
        guard !shown.isEmpty else { return nil }
        return submenu("Folder Structure", symbol: "folder.badge.gearshape", shown)
    }

    /// Suggest Names ▸: for the selection first, then for the whole folder.
    private func suggestNamesMenu() -> NSMenuItem {
        let selection = ClosureMenuItem(
            String(localized: "For Selection…"), symbol: "text.badge.star"
        ) { [browser, undoManager] in
            NameReviewWindow.show(for: browser, undoManager: undoManager)
        }
        let menu = submenu(
            "Suggest Names", symbol: "text.badge.star",
            [selection, suggestNamesForFolderItem(title: "For Whole Folder…")])
        menu.isEnabled = browser.canSuggestNames
        return menu
    }

    /// Suggest Names for the whole folder shown, whatever is selected.
    func suggestNamesForFolderItem(title: String.LocalizationValue) -> NSMenuItem {
        ClosureMenuItem(
            String(localized: title), symbol: "text.badge.star", enabled: browser.canSuggestNames
        ) { [browser, undoManager] in
            NameReviewWindow.showWholeFolder(of: browser, undoManager: undoManager)
        }
    }

    private func submenu(
        _ title: String.LocalizationValue, symbol: String, _ items: [NSMenuItem]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: title), action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let menu = NSMenu(title: item.title)
        menu.autoenablesItems = false
        menu.items = items
        item.submenu = menu
        return item
    }
}
