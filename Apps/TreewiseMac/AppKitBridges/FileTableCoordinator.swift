import AppKit
import TreewiseCore
import TreewiseUI

/// Feeds the list's table view and turns its events into `FileTableActions`.
@MainActor
final class FileTableCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private static let iconSize = NSSize(width: 16, height: 16)
    /// Space between a cell's edges and its contents.
    private static let cellPadding: CGFloat = 2
    /// Space between the icon and the name.
    private static let iconSpacing: CGFloat = 6

    /// The alpha of a cut item's row (PLAN.md §4.3).
    private static let cutAlpha: CGFloat = 0.5

    weak var table: PaneTableView?
    var items: [FileItem] = []
    var actions: FileTableActions?
    /// Makes the pane active on a click anywhere in its scroll view.
    var clickFocus: PaneClickFocus?
    var folder: FileItem?
    /// The item whose name is being edited, if any.
    var renaming: FileItem?
    /// Whether names show their extension (ADR 0023).
    private var showsExtensions = true
    private var cutItems: Set<FileItem.ID> = []
    private var downloads: [FileItem.ID: Double] = [:]
    /// Set while the table is brought in line with the state, so its own
    /// notifications are not sent back as user actions.
    private var isApplyingState = false
    private let dates = ItemDateFormatter(
        calendar: .autoupdatingCurrent, locale: .autoupdatingCurrent, timeZone: .autoupdatingCurrent
    )
    private let sizes = ItemSizeFormatter(locale: .autoupdatingCurrent)
    private let kinds = KindFormatter(locale: .autoupdatingCurrent)

    func attach(to table: PaneTableView) {
        self.table = table
        for column in FileTableColumn.allCases {
            table.addTableColumn(column.makeTableColumn())
        }
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.style = .fullWidth
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(openClickedRow)
        table.registerForDraggedTypes(DropRouting.pasteboardTypes)
        table.setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: true)
        table.setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: false)
        table.onFocus = { [weak self] in self?.actions?.focus() }
        table.commands = TableCommands(
            cut: { [weak self] in self?.actions?.cut() },
            copy: { [weak self] in self?.actions?.copy() },
            paste: { [weak self] in self?.actions?.paste() },
            rename: { [weak self] row in self?.beginRename(row: row) },
            canPaste: { [weak self] in self?.actions?.canPaste() ?? false },
            menu: { [weak self] row in self?.contextMenu(row: row) },
            selectedURLs: { [weak self] in self?.selectedURLs() ?? [] })
    }

    func update(with view: FileTableView) {
        guard let table else { return }
        actions = view.actions
        folder = view.folder
        isApplyingState = true
        defer { isApplyingState = false }
        if items != view.items || cutItems != view.cutItems
            || showsExtensions != view.showsExtensions
        {
            items = view.items
            cutItems = view.cutItems
            showsExtensions = view.showsExtensions
            table.reloadData()
        }
        if downloads != view.downloads {
            downloads = view.downloads
            showDownloads(in: table)
        }
        if table.rowHeight != view.rowHeight { table.rowHeight = view.rowHeight }
        let column = FileTableColumn(view.sort.column)
        table.sortDescriptors = [
            NSSortDescriptor(key: column.rawValue, ascending: view.sort.ascending)
        ]
        let rows = IndexSet(items.indices.filter { view.selection.contains(items[$0].id) })
        if table.selectedRowIndexes != rows {
            table.selectRowIndexes(rows, byExtendingSelection: false)
        }
        table.isActivePane = view.isActive
        if view.isActive { PaneFocus.follow(table) }
        if let request = view.revealRequest, let row = items.firstIndex(where: { $0.id == request })
        {
            view.actions.revealed()
            DispatchQueue.main.async { [weak table] in table?.scrollRowToVisible(row) }
        }
        if let request = view.renameRequest, let row = items.firstIndex(where: { $0.id == request })
        {
            let suggests = view.actions.renameStarted()
            DispatchQueue.main.async { [weak self] in
                self?.beginRename(row: row, suggests: suggests)
            }
        }
    }

    /// Shows the downloads in the rows on screen, without reloading a row
    /// that may be being renamed.
    private func showDownloads(in table: NSTableView) {
        for (row, item) in items.enumerated() where item.isOnlyOnline {
            let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false)
            (cell as? FileNameCell)?.showCloudStatus(
                isOnlyOnline: item.isOnlyOnline, download: downloads[item.id])
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = PaneRowView()
        rowView.table = table
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        guard let identifier = tableColumn?.identifier,
            let column = FileTableColumn(rawValue: identifier.rawValue), items.indices.contains(row)
        else { return nil }
        let cell =
            tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? Self.makeCell(
                identifier, column: column, alignment: column == .size ? .right : .left)
        let item = items[row]
        cell.textField?.stringValue = text(of: item, in: column)
        cell.alphaValue = cutItems.contains(item.id) ? Self.cutAlpha : 1
        if column == .name {
            let icon = ItemIcon.image(for: item)
            icon.size = Self.iconSize
            cell.imageView?.image = icon
            (cell as? FileNameCell)?.showCloudStatus(
                isOnlyOnline: item.isOnlyOnline, download: downloads[item.id])
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingState, let table else { return }
        let ids = table.selectedRowIndexes.compactMap {
            items.indices.contains($0) ? items[$0].id : nil
        }
        actions?.select(Set(ids))
        QuickLookSource.shared.follow(selectedURLs())
    }

    private func selectedURLs() -> [URL] {
        (table?.selectedRowIndexes ?? []).compactMap {
            items.indices.contains($0) ? items[$0].id.diskURL : nil
        }
    }

    func tableView(
        _ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]
    ) {
        guard !isApplyingState, let key = tableView.sortDescriptors.first?.key,
            let column = FileTableColumn(rawValue: key)
        else { return }
        actions?.sort(column.sortColumn)
    }

    /// The context menu for the selection, or for the folder without one.
    private func contextMenu(row: Int?) -> NSMenu? {
        guard let table else { return nil }
        let rows = row == nil ? IndexSet() : table.selectedRowIndexes
        return actions?.contextMenu(
            rows.compactMap { items.indices.contains($0) ? items[$0] : nil })
    }

    /// The name the list shows: without its extension when the setting hides them.
    func shownName(of item: FileItem) -> String {
        DisplayName.text(for: item, showsExtension: showsExtensions)
    }

    @objc private func openClickedRow() {
        guard let table, items.indices.contains(table.clickedRow) else { return }
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        actions?.open(items[table.clickedRow], flags.contains(.command), flags.contains(.option))
    }

    private func text(of item: FileItem, in column: FileTableColumn) -> String {
        switch column {
        case .name: shownName(of: item)
        case .dateModified: dates.string(forModifiedOf: item, relativeTo: Date())
        case .size: sizes.string(for: item)
        case .kind: kinds.string(for: item)
        }
    }

    private static func makeCell(
        _ identifier: NSUserInterfaceItemIdentifier, column: FileTableColumn,
        alignment: NSTextAlignment
    ) -> NSTableCellView {
        let withIcon = column == .name
        let cell = withIcon ? FileNameCell() : NSTableCellView()
        cell.identifier = identifier
        let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingMiddle
        text.alignment = alignment
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(text)
        cell.textField = text
        var constraints = [text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)]
        if let nameCell = cell as? FileNameCell {
            nameCell.placeCloudStatus(after: text, padding: cellPadding)
        } else {
            constraints.append(
                text.trailingAnchor.constraint(
                    equalTo: cell.trailingAnchor, constant: -cellPadding))
        }
        if withIcon {
            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(icon)
            cell.imageView = icon
            constraints += [
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: cellPadding),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: iconSize.width),
                icon.heightAnchor.constraint(equalToConstant: iconSize.height),
                text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: iconSpacing),
            ]
        } else {
            constraints.append(
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: cellPadding))
        }
        NSLayoutConstraint.activate(constraints)
        return cell
    }
}
