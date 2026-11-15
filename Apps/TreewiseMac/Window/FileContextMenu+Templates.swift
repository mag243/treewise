import AppKit
import TreewiseCore
import TreewiseUI

extension FileContextMenu {
    /// On one folder, its templates' items, Add Missing Folders… and copying and pasting its
    /// structure (ADR 0091, ADR 0099, ADR 0102).
    func addTemplateItems(for items: [FileItem], to menu: NSMenu) {
        guard items.count == 1, items[0].kind == .folder, ArchivePath(items[0].id) == nil else {
            return
        }
        let shown = [
            FolderTemplateMenu.newFoldersItem(
                in: items[0].id, browser: browser, undoManager: undoManager),
            FolderTemplateMenu.missingItem(
                for: items[0].id, browser: browser, undoManager: undoManager),
            FolderTemplateMenu.saveItem(for: items[0], browser: browser),
            FolderTemplateMenu.copyItem(for: items[0], browser: browser),
            FolderTemplateMenu.pasteItem(
                in: items[0].id, browser: browser, undoManager: undoManager),
        ].compactMap(\.self)
        guard !shown.isEmpty else { return }
        menu.addItem(.separator())
        for item in shown { menu.addItem(item) }
    }
}
