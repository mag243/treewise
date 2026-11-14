import AppKit
import TreewiseUI

/// Puts the template items in the File menu as it opens, below New Folder (ADR 0091): New
/// Folders from Template ▸ for the folder shown, and Save Folder Structure as Template… for a
/// single folder selected. The menu is built once, so its delegate adds them each time.
@MainActor
final class FileMenuTemplates: NSObject, NSMenuDelegate {
    /// The File menu's delegate, kept for the app's life.
    static let shared = FileMenuTemplates()
    private static let tag = 0x7E3D

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items = menu.items.filter { $0.tag != Self.tag }
        guard let window = NSApp.keyWindow?.windowController as? BrowserWindowController,
            let newFolder = menu.items.firstIndex(where: {
                $0.action == #selector(BrowserWindowController.newFolder(_:))
            })
        else { return }
        let browser = window.browser
        var added: [NSMenuItem] = []
        if let item = FolderTemplateMenu.newFoldersItem(
            in: browser.layout.focusedPane.activeTab.folder, browser: browser,
            undoManager: SharedUndo.manager, enabled: browser.canAddItems)
        {
            added.append(item)
        }
        let selected = browser.selectedItems
        if selected.count == 1,
            let item = FolderTemplateMenu.saveItem(for: selected[0], browser: browser)
        {
            added.append(item)
        }
        for (offset, item) in added.enumerated() {
            item.tag = Self.tag
            menu.insertItem(item, at: newFolder + 1 + offset)
        }
    }
}
