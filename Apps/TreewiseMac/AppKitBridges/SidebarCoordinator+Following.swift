import AppKit
import TreewiseCore

/// The tree follows the folders it shows open, and the folder a pane shows (ADR 0112): a
/// change reads the folder's subfolders again, and the rows still there are kept, with
/// their open folders.
extension SidebarCoordinator {
    func outlineViewItemDidExpand(_ notification: Notification) {
        if let node = notification.userInfo?["NSObject"] as? SidebarNode {
            followRepository(openIn: node)
        }
        guard let node = notification.userInfo?["NSObject"] as? SidebarNode,
            node.children != nil, let folder = node.item?.id,
            !watches.watches(ObjectIdentifier(node))
        else { return }
        // Opened again after it was closed, and not followed meanwhile: its rows may have
        // gained or lost subfolders too.
        watch(node, folder: folder)
        Task { await readAgain(node, folder: folder, checkingTriangles: true) }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? SidebarNode else { return }
        watches.end([ObjectIdentifier(node)])
        gitFollows.end([ObjectIdentifier(node)])
    }

    /// Follows the folder of an open row until it closes or leaves the tree.
    func watch(_ node: SidebarNode, folder: FileItem.ID) {
        let row = ObjectIdentifier(node)
        guard let changes, !watches.watches(row) else { return }
        let stream = changes(folder)
        let task = Task { [weak self, weak node] in
            for await _ in stream {
                guard let self, let node else { return }
                await readAgain(node, folder: folder)
            }
        }
        watches.add(task, for: row)
    }

    /// Reads the folder a pane shows again in the tree, where its row has been read.
    func readAgain(shown folder: FileItem.ID) {
        guard let node = readRow(of: folder) else { return }
        Task { await readAgain(node, folder: folder) }
    }

    /// Reads again the rows of folders whose entries Treewise changed (ADR 0112): a row read
    /// before gets its subfolders anew, and one never opened is checked for subfolders, so
    /// its triangle comes or goes, open in the tree or not.
    func readAgain(changed folders: Set<FileItem.ID>) {
        for folder in folders {
            for node in rows(of: folder) {
                if node.children != nil {
                    Task { await readAgain(node, folder: folder) }
                } else {
                    Task { await dropTriangles(of: [node]) }
                }
            }
        }
    }

    /// Reads a row's subfolders again: a row still there is kept, with its open folders
    /// and the selection; a new folder gets a row; a gone one loses its row and its watch.
    /// `checkingTriangles` checks the rows' triangles even when the subfolders are the same.
    func readAgain(
        _ node: SidebarNode, folder: FileItem.ID, checkingTriangles: Bool = false
    ) async {
        guard let loadSubfolders, let outline else { return }
        let subfolders = await loadSubfolders(folder)
        guard let before = node.children else { return }
        guard before.compactMap(\.item?.id) != subfolders.map(\.id) else {
            if checkingTriangles { await checkTriangles(of: before) }
            return
        }
        let pairs = before.compactMap { row in row.item.map { ($0.id, row) } }
        let kept = Dictionary(pairs, uniquingKeysWith: Self.first)
        let open = before.filter { outline.isItemExpanded($0) }
        let after = subfolders.map { kept[$0.id] ?? SidebarNode(item: $0, expandable: true) }
        node.children = after
        let staying = Set(after.map(ObjectIdentifier.init))
        endWatching(before.filter { !staying.contains(ObjectIdentifier($0)) })
        // Reloading a row during a drag drops the drag's target; it waits until the drag ends.
        if springLoading.isDragging {
            redrawnAfterDrag.append(node)
            return
        }
        outline.reloadItem(node, reloadChildren: true)
        for row in open where staying.contains(ObjectIdentifier(row)) { outline.expandItem(row) }
        if let currentFolder { selectRow(of: currentFolder) }
        await checkTriangles(of: after)
    }

    /// Gives a row back its disclosure triangle when its folder may hold subfolders again,
    /// and takes it off where it holds none (ADR 0108).
    private func checkTriangles(of rows: [SidebarNode]) async {
        if let subfolderPresence {
            for row in rows where row.children?.isEmpty == true {
                guard let folder = row.item?.id, await subfolderPresence(folder) != .absent,
                    row.children?.isEmpty == true
                else { continue }
                row.children = nil
                outline?.reloadItem(row)
            }
        }
        await dropTriangles(of: rows)
    }

    private static func first(_ row: SidebarNode, _: SidebarNode) -> SidebarNode { row }

    /// The row in Locations whose subfolders have been read, for `folder`.
    private func readRow(of folder: FileItem.ID) -> SidebarNode? {
        rows(of: folder).first { $0.children != nil }
    }

    /// Every row in Locations for `folder`, read or not.
    private func rows(of folder: FileItem.ID) -> [SidebarNode] {
        var pending = Array(roots.dropFirst())
        var found: [SidebarNode] = []
        while let node = pending.popLast() {
            if node.item?.id == folder { found.append(node) }
            pending += node.children ?? []
        }
        return found
    }

    /// Stops following the rows and every row below them.
    private func endWatching(_ rows: [SidebarNode]) {
        var pending = rows
        var ended: [ObjectIdentifier] = []
        while let row = pending.popLast() {
            ended.append(ObjectIdentifier(row))
            pending += row.children ?? []
        }
        watches.end(ended)
        gitFollows.end(ended)
    }
}
