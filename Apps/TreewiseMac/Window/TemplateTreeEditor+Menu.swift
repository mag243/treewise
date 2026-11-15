import AppKit

/// The context menu of a template's tree in Settings (ADR 0105): New Folder, Rename,
/// Insert Field ▸, Remove Name Settings and Delete, for the folder clicked.
extension TemplateTreeEditor {
    func folderMenuItems() -> [NSMenuItem] {
        guard let node = selectedNode else { return [] }
        let add: () -> Void = { [weak self] in self?.addFolder() }
        let rename: () -> Void = { [weak self] in self?.renameSelected() }
        let removeNames: () -> Void = { [weak self] in self?.removeNames() }
        let delete: () -> Void = { [weak self] in self?.removeFolder() }
        var items: [NSMenuItem] = [
            ClosureMenuItem(
                String(localized: "New Folder"), symbol: "folder.badge.plus", handler: add),
            ClosureMenuItem(String(localized: "Rename"), symbol: "pencil", handler: rename),
            insertFieldItem(),
        ]
        if node.tree.names != nil {
            items.append(
                ClosureMenuItem(
                    String(localized: "Remove Name Settings"), symbol: "textformat",
                    handler: removeNames))
        }
        items += [
            .separator(),
            ClosureMenuItem(
                String(localized: "Delete"), symbol: "trash", enabled: !node.path.isEmpty,
                handler: delete),
        ]
        return items
    }

    /// Insert Field ▸ with the fields the pop-up below the tree offers for this folder.
    private func insertFieldItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: "Insert Field"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for field in insert.itemArray.dropFirst() {
            let copy = NSMenuItem(
                title: field.title, action: #selector(insertField(_:)), keyEquivalent: "")
            copy.target = self
            copy.representedObject = field.representedObject
            copy.isEnabled = field.isEnabled
            submenu.addItem(copy)
        }
        item.submenu = submenu
        return item
    }
}
