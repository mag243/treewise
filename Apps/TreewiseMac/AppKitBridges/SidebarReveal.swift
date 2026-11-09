import AppKit
import TreewiseCore

/// Opening the sidebar's tree down to the folder a tab shows.
extension SidebarCoordinator {
    /// Opens the tree along `path` when that way is new.
    func follow(_ path: [FileItem.ID]?) {
        guard path != revealedPath, !roots.isEmpty else { return }
        revealedPath = path
        revealTask?.cancel()
        guard let path else { return }
        revealTask = Task { await reveal(path) }
    }

    /// Opens the folders along `path`, from the innermost location on it, and
    /// brings the last one into view. The last one itself stays closed.
    private func reveal(_ path: [FileItem.ID]) async {
        guard let outline, roots.count > 1, let computer = roots[1].children?.first,
            let last = path.last
        else { return }
        var rows = computer.children ?? []
        guard
            let start = path.lastIndex(where: { id in rows.contains { $0.item?.id == id } })
        else { return }
        var target: SidebarNode?
        for id in path[start...] {
            guard let node = rows.first(where: { $0.item?.id == id }) else { return }
            target = node
            guard id != last else { break }
            await open(node)
            guard !Task.isCancelled else { return }
            rows = node.children ?? []
        }
        selectRow(of: last)
        if let target { outline.scrollRowToVisible(outline.row(forItem: target)) }
    }

    private func open(_ node: SidebarNode) async {
        if node.children == nil, let folder = node.item {
            await load(node, folder: folder.id)
        } else {
            outline?.expandItem(node)
        }
    }
}
