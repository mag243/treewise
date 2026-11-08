import AppKit
import TreewiseCore
import TreewiseUI

/// Feeds the sidebar's outline view and loads folders as they expand.
@MainActor
final class SidebarCoordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private static let iconSize = NSSize(width: 16, height: 16)
    private static let cellIdentifier = NSUserInterfaceItemIdentifier("SidebarCell")
    private static let headerIdentifier = NSUserInterfaceItemIdentifier("SidebarHeader")

    private weak var outline: NSOutlineView?
    private(set) var roots: [SidebarNode] = []
    private var shown: (favorites: [FileItem], locations: [FileItem]) = ([], [])
    /// The hidden-files setting the loaded folders follow.
    private var showsHiddenFiles = false
    private var loadSubfolders: ((FileItem.ID) async -> [FileItem])?
    private var select: ((FileItem) -> Void)?
    /// Ejects volumes: the eject buttons and the context menu (ADR 0044).
    private(set) var eject: (([FileItem]) -> Void)?
    private(set) var drop: DropAction?
    private(set) var favoriteActions: SidebarFavoriteActions?
    /// Keeps folders closed while a drag only passes over them.
    let springLoading = SidebarSpringLoading()
    /// Set while the selection follows the active pane, so it is not sent back
    /// as a choice of the user.
    private var isApplyingState = false

    func attach(to outline: NSOutlineView) {
        self.outline = outline
        let column = NSTableColumn(identifier: Self.cellIdentifier)
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.style = .sourceList
        outline.floatsGroupRows = false
        outline.registerForDraggedTypes(DropRouting.pasteboardTypes + [Self.favoriteDragType])
        outline.setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: true)
        outline.setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: false)
        outline.dataSource = self
        outline.delegate = self
        (outline as? SidebarOutline)?.dragEnded = { [weak self] in self?.springLoading.end() }
        (outline as? SidebarOutline)?.rowMenu = { [weak self, weak outline] node in
            guard let outline else { return nil }
            return self?.menu(for: node, in: outline)
        }
    }

    func update(with view: SidebarOutlineView) {
        loadSubfolders = view.loadSubfolders
        select = view.select
        eject = view.eject
        drop = view.drop
        favoriteActions = view.favoriteActions
        defer { selectRow(of: view.currentFolder) }
        if showsHiddenFiles != view.showsHiddenFiles {
            showsHiddenFiles = view.showsHiddenFiles
            reloadFolders()
        }
        guard let outline, shown.favorites != view.favorites || shown.locations != view.locations
        else { return }
        let onlyFavoritesChanged = shown.locations == view.locations && !roots.isEmpty
        shown = (view.favorites, view.locations)
        let favorites = view.favorites.map { SidebarNode(item: $0, expandable: false) }
        // The tree keeps its open folders when only the favorites change.
        if onlyFavoritesChanged, let root = roots.first {
            root.children = favorites
            outline.reloadItem(root, reloadChildren: true)
            return
        }
        let computer = SidebarNode(
            computer: String(localized: "This Mac", comment: "Sidebar row that holds the volumes"),
            children: view.locations.map { SidebarNode(item: $0, expandable: true) })
        roots = [
            SidebarNode(
                section: String(localized: "Favorites", comment: "Sidebar section"),
                children: favorites),
            SidebarNode(
                section: String(localized: "Locations", comment: "Sidebar section"),
                children: [computer]),
        ]
        outline.reloadData()
        for root in roots {
            outline.expandItem(root)
        }
        outline.expandItem(computer)
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let node = item as? SidebarNode else { return roots.count }
        return node.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let node = item as? SidebarNode else { return roots[index] }
        return node.children?[index] ?? roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? SidebarNode)?.isExpandable ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        guard let node = item as? SidebarNode, case .section = node.content else { return false }
        return true
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? SidebarNode)?.item != nil
    }

    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        if let node = item as? SidebarNode, !springLoading.mayExpand(node) { return false }
        guard let node = item as? SidebarNode, node.children == nil, let folder = node.item else {
            return true
        }
        Task { await load(node, folder: folder.id) }
        return false
    }

    func outlineView(
        _ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any
    ) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        switch node.content {
        case .section(let title):
            let cell = reusedCell(Self.headerIdentifier, in: outlineView, withIcon: false)
            cell.textField?.stringValue = title
            return cell
        case .computer(let title):
            let cell = reusedCell(Self.cellIdentifier, in: outlineView, withIcon: true)
            cell.textField?.stringValue = title
            cell.imageView?.image = FolderIcon.image(for: .computer)
            (cell as? SidebarCell)?.eject = nil
            return cell
        case .item(let folder):
            let cell = reusedCell(Self.cellIdentifier, in: outlineView, withIcon: true)
            cell.textField?.stringValue = folder.name
            let icon = FolderIcon.image(for: folder.id)
            // A symbol keeps its own proportions; a file's icon comes in many sizes.
            if !FolderIcon.isHome(folder.id) { icon.size = Self.iconSize }
            cell.imageView?.image = icon
            (cell as? SidebarCell)?.eject =
                folder.isEjectable ? { [weak self] in self?.eject?([folder]) } : nil
            return cell
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingState, let outline,
            let node = outline.item(atRow: outline.selectedRow) as? SidebarNode,
            let folder = node.item
        else { return }
        select?(folder)
    }

    /// Selects the visible row that `SidebarSelection` chooses for `folder`, or none.
    private func selectRow(of folder: FileItem.ID) {
        guard let outline else { return }
        let candidates = (0..<outline.numberOfRows).compactMap {
            candidate(atRow: $0, of: outline, for: folder)
        }
        let row = SidebarSelection.row(
            among: candidates, selected: outline.selectedRowIndexes.first)
        let rows = row.map { IndexSet(integer: $0) } ?? IndexSet()
        guard outline.selectedRowIndexes != rows else { return }
        isApplyingState = true
        outline.selectRowIndexes(rows, byExtendingSelection: false)
        isApplyingState = false
    }

    /// The row as a candidate for selecting `folder`, if it stands for that folder.
    private func candidate(
        atRow row: Int, of outline: NSOutlineView, for folder: FileItem.ID
    ) -> SidebarSelection.Candidate? {
        guard let node = outline.item(atRow: row) as? SidebarNode, node.item?.id == folder
        else { return nil }
        let isFavorite = outline.parent(forItem: node) as? SidebarNode === roots.first
        return SidebarSelection.Candidate(row: row, isFavorite: isFavorite)
    }

    /// Loads the open locations of the tree again and forgets the closed
    /// ones, after the hidden-files setting changed. A reloaded location gets
    /// new rows, so folders open inside it close.
    private func reloadFolders() {
        guard let outline, roots.count > 1, let computer = roots[1].children?.first else { return }
        for node in computer.children ?? [] {
            guard node.children != nil, let folder = node.item else { continue }
            if outline.isItemExpanded(node) {
                Task { await load(node, folder: folder.id) }
            } else {
                node.children = nil
                outline.reloadItem(node, reloadChildren: true)
            }
        }
    }

    private func load(_ node: SidebarNode, folder: FileItem.ID) async {
        guard let loadSubfolders else { return }
        let subfolders = await loadSubfolders(folder)
        node.children = subfolders.map { SidebarNode(item: $0, expandable: true) }
        outline?.reloadItem(node, reloadChildren: true)
        outline?.expandItem(node)
    }

    private func reusedCell(
        _ identifier: NSUserInterfaceItemIdentifier, in outline: NSOutlineView, withIcon: Bool
    ) -> NSTableCellView {
        if let cell = outline.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        {
            return cell
        }
        return SidebarCell(identifier: identifier, withIcon: withIcon, iconSize: Self.iconSize)
    }
}
