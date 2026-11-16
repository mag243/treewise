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
        guard outline != nil, roots.count > 1, let computer = roots[1].children?.first,
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
        if let target { bringToMiddleIfOutOfView(target) }
    }

    /// Scrolls a row that is not wholly in view to the middle of the tree, as far as the
    /// tree goes; a row in view stays where it is, so the tree does not move under the
    /// pointer. A restored window takes its size and its sidebar's width after the tree is
    /// opened, so the row is placed once the window is laid out.
    private func bringToMiddleIfOutOfView(_ node: SidebarNode) {
        DispatchQueue.main.async { [weak self, weak node] in
            guard let self, let node, let outline,
                let scrollView = outline.enclosingScrollView
            else { return }
            outline.window?.layoutIfNeeded()
            let row = outline.row(forItem: node)
            guard row >= 0 else { return }
            let frame = outline.rect(ofRow: row)
            let clip = scrollView.contentView
            guard !clip.documentVisibleRect.contains(frame) else { return }
            let insets = scrollView.contentInsets
            let highest = -insets.top
            let lowest = max(
                highest, outline.frame.height - clip.bounds.height + insets.bottom)
            let top = min(max(frame.midY - clip.bounds.height / 2, highest), lowest)
            clip.scroll(to: NSPoint(x: clip.bounds.minX, y: top))
            scrollView.reflectScrolledClipView(clip)
        }
    }

    private func open(_ node: SidebarNode) async {
        if node.children == nil, let folder = node.item {
            await load(node, folder: folder.id)
        } else {
            outline?.expandItem(node)
        }
    }
}
