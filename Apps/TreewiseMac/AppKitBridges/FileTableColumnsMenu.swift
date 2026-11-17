import AppKit
import TreewiseCore
import TreewiseUI

/// The list headers' menu, as in Finder: a Control-click or right-click on a header shows
/// or hides the columns beside the name (ADR 0127).
extension FileTableCoordinator {
    /// Gives the table's headers the menu of columns.
    func attachColumnsMenu(to table: NSTableView) {
        let menu = NSMenu()
        for column in FileTableColumn.allCases {
            guard let folderColumn = column.folderColumn else { continue }
            let item = NSMenuItem(
                title: column.title, action: #selector(toggleColumn(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = folderColumn.rawValue
            menu.addItem(item)
        }
        table.headerView?.menu = menu
    }

    /// Shows the columns `layout` shows and hides the others, and ticks them in the menu.
    func showColumns(_ layout: TableColumnLayout, in table: NSTableView) {
        for column in FileTableColumn.allCases {
            guard let folderColumn = column.folderColumn,
                let tableColumn = table.tableColumn(withIdentifier: column.identifier)
            else { continue }
            let isHidden = !layout.isShown(folderColumn)
            if tableColumn.isHidden != isHidden { tableColumn.isHidden = isHidden }
        }
        for item in table.headerView?.menu?.items ?? [] {
            guard let raw = item.representedObject as? String,
                let folderColumn = FolderColumn(rawValue: raw)
            else { continue }
            item.state = layout.isShown(folderColumn) ? .on : .off
        }
    }

    @objc private func toggleColumn(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String,
            let folderColumn = FolderColumn(rawValue: raw)
        else { return }
        actions?.toggleColumn(folderColumn)
    }
}
