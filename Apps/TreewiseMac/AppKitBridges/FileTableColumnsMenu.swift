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
        var changed = false
        for column in FileTableColumn.allCases {
            guard let folderColumn = column.folderColumn,
                let tableColumn = table.tableColumn(withIdentifier: column.identifier)
            else { continue }
            let isHidden = !layout.isShown(folderColumn)
            if tableColumn.isHidden != isHidden {
                tableColumn.isHidden = isHidden
                changed = true
            }
        }
        if changed { fitNameColumn(in: table) }
        for item in table.headerView?.menu?.items ?? [] {
            guard let raw = item.representedObject as? String,
                let folderColumn = FolderColumn(rawValue: raw)
            else { continue }
            item.state = layout.isShown(folderColumn) ? .on : .off
        }
    }

    /// Gives the name the width the list leaves beside the columns that show, as resizing
    /// the window does. AppKit hands a hidden column's width to the name instead, and a list
    /// that was wider than its window then stays so, with the name running under what lies
    /// beside the window.
    private func fitNameColumn(in table: NSTableView) {
        guard let name = table.tableColumn(withIdentifier: FileTableColumn.name.identifier),
            let visible = table.enclosingScrollView?.contentView.bounds.width
        else { return }
        let others = table.tableColumns.filter { !$0.isHidden && $0 !== name }
        let spacing = table.intercellSpacing.width * CGFloat(others.count + 1)
        name.width = max(name.minWidth, visible - others.reduce(0) { $0 + $1.width } - spacing)
    }

    @objc private func toggleColumn(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String,
            let folderColumn = FolderColumn(rawValue: raw)
        else { return }
        actions?.toggleColumn(folderColumn)
    }
}
