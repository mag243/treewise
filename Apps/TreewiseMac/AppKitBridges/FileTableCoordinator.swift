import AppKit
import TreewiseCore
import TreewiseUI

/// Feeds the list's table view and turns its events into `FileTableActions`.
@MainActor
final class FileTableCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    /// Space between a cell's edges and its contents.
    private static let cellPadding: CGFloat = 2
    weak var table: PaneTableView?
    var items: [FileItem] = []
    var actions: FileTableActions?
    /// Makes the pane active on a click anywhere in its scroll view.
    var clickFocus: PaneClickFocus?
    var folder: FileItem?
    /// The columns the user chose, which give way where the list is too narrow for them.
    var chosenColumns: TableColumnLayout?
    /// Whether they give way, as in a half of a split window.
    var columnsGiveWay = false
    /// Fits the columns again when the list's width changes.
    var resizing: NSObjectProtocol?
    /// Renames items in place, in the name's field.
    lazy var renamer = NameFieldRenamer(
        actions: { [weak self] in self?.actions },
        shownName: { [weak self] item in self?.shownName(of: item) ?? item.name },
        home: { [weak self] in self?.table })
    /// Whether names show their extension (ADR 0023).
    private var showsExtensions = true
    private var cutItems: Set<FileItem.ID> = []
    private var downloads: [FileItem.ID: Double] = [:]
    private var gitStates: [FileItem.ID: GitItemState] = [:]
    /// Set while the table is brought in line with the state, so its own
    /// notifications are not sent back as user actions.
    private var isApplyingState = false
    /// The selection the table last took from the state or gave to it. The state's selection
    /// is shown only when it changes or the rows do: an update that comes while the mouse is
    /// still down, such as the pane taking the focus on a ⌘-click, must not put back the
    /// selection AppKit has not reported yet.
    private var shownSelection: Set<FileItem.ID> = []
    private let formats = ItemFormats()

    func attach(to table: PaneTableView) {
        self.table = table
        for column in FileTableColumn.allCases {
            table.addTableColumn(column.makeTableColumn())
        }
        attachColumnsMenu(to: table)
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.style = .fullWidth
        // A narrower list, as beside the details pane, makes the name narrower first and
        // scrolls sideways only once it is at its narrowest, as Finder does.
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
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
            selectedURLs: { [weak self] in await self?.selectedURLs() ?? [] })
    }

    func update(with view: FileTableContent) {
        guard let table else { return }
        actions = view.actions
        folder = view.folder
        isApplyingState = true
        defer { isApplyingState = false }
        let itemsChanged = items != view.items
        if itemsChanged || cutItems != view.cutItems
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
        if gitStates != view.gitStates {
            gitStates = view.gitStates
            if !itemsChanged { showGitStates(in: table) }
        }
        if table.rowHeight != view.rowHeight { table.rowHeight = view.rowHeight }
        columnsGiveWay = view.columnsGiveWay
        showColumns(view.columns, sortedBy: view.sort, in: table)
        if itemsChanged || view.selection != shownSelection { show(view.selection, in: table) }
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

    /// Selects the rows of `selection`, as the state has it.
    private func show(_ selection: Set<FileItem.ID>, in table: NSTableView) {
        shownSelection = selection
        let rows = IndexSet(items.indices.filter { selection.contains(items[$0].id) })
        if table.selectedRowIndexes != rows {
            table.selectRowIndexes(rows, byExtendingSelection: false)
        }
    }

    /// Shows the downloads in the rows that have a view, those on screen and those AppKit
    /// keeps ready beside them, without reloading a row that may be being renamed; a row
    /// made later reads them when it is shown.
    private func showDownloads(in table: NSTableView) {
        table.enumerateAvailableRowViews { _, row in
            guard items.indices.contains(row), items[row].isOnlyOnline else { return }
            let item = items[row]
            let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false)
            (cell as? FileNameCell)?.showCloudStatus(
                isOnlyOnline: item.isOnlyOnline, download: downloads[item.id])
        }
    }

    /// Shows the git states in the rows that have a view, as `showDownloads` does, without
    /// reloading a row that may be being renamed.
    private func showGitStates(in table: NSTableView) {
        let gitColumn = table.column(withIdentifier: FileTableColumn.git.identifier)
        table.enumerateAvailableRowViews { _, row in
            guard items.indices.contains(row) else { return }
            let state = gitStates[items[row].id]
            let name = table.view(atColumn: 0, row: row, makeIfNecessary: false)
            (name as? FileNameCell)?.showGitState(state)
            guard gitColumn >= 0,
                let cell = table.view(atColumn: gitColumn, row: row, makeIfNecessary: false)
                    as? NSTableCellView
            else { return }
            cell.textField?.stringValue = text(of: items[row], in: .git)
            (cell as? GitStateCell)?.state = state
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
        cell.alphaValue = cutItems.contains(item.id) ? Tint.cut : 1
        (cell as? GitStateCell)?.state = gitStates[item.id]
        if column == .name {
            let icon = ItemIcon.image(for: item)
            icon.size = ListMetrics.iconSize
            cell.imageView?.image = icon
            (cell as? FileNameCell)?.showCloudStatus(
                isOnlyOnline: item.isOnlyOnline, download: downloads[item.id])
            (cell as? FileNameCell)?.showGitState(gitStates[item.id])
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingState, let table else { return }
        let ids = table.selectedRowIndexes.compactMap {
            items.indices.contains($0) ? items[$0].id : nil
        }
        shownSelection = Set(ids)
        actions?.select(Set(ids))
        QuickLookSource.shared.follow { [weak self] in await self?.selectedURLs() ?? [] }
    }

    private func selectedURLs() async -> [URL] {
        let chosen = (table?.selectedRowIndexes ?? []).compactMap {
            items.indices.contains($0) ? items[$0] : nil
        }
        return await actions?.previewURLs(chosen) ?? []
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

    /// Shows the columns chosen and the sort in the headers.
    private func showColumns(
        _ columns: TableColumnLayout, sortedBy sort: ItemSort, in table: NSTableView
    ) {
        showColumns(columns, in: table)
        let column = FileTableColumn(sort.column)
        table.sortDescriptors = [NSSortDescriptor(key: column.rawValue, ascending: sort.ascending)]
    }

    @objc private func openClickedRow() {
        guard let table, items.indices.contains(table.clickedRow) else { return }
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        actions?.open(items[table.clickedRow], flags.contains(.command), flags.contains(.option))
    }

    private func text(of item: FileItem, in column: FileTableColumn) -> String {
        switch column {
        case .name: shownName(of: item)
        case .dateModified: formats.date(of: item)
        case .dateCreated: formats.date(item.created)
        case .dateAdded: formats.date(item.added)
        case .size: formats.size(of: item)
        case .kind: formats.kind(of: item)
        case .git: gitStates[item.id].map { GitText.state($0, locale: .autoupdatingCurrent) } ?? ""
        }
    }

    private static func makeCell(
        _ identifier: NSUserInterfaceItemIdentifier, column: FileTableColumn,
        alignment: NSTextAlignment
    ) -> NSTableCellView {
        let withIcon = column == .name
        let cell =
            withIcon ? FileNameCell() : column == .git ? GitStateCell() : NSTableCellView()
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
            (cell as? FileNameCell)?.placeGitBadge(on: icon)
            constraints += [
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: cellPadding),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: ListMetrics.iconSize.width),
                icon.heightAnchor.constraint(equalToConstant: ListMetrics.iconSize.height),
                text.leadingAnchor.constraint(
                    equalTo: icon.trailingAnchor, constant: ListMetrics.iconSpacing),
            ]
        } else {
            constraints.append(
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: cellPadding))
        }
        NSLayoutConstraint.activate(constraints)
        return cell
    }
}
