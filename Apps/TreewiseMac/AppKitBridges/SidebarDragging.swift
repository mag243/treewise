import AppKit
import TreewiseCore

/// Dragging from and onto the sidebar (ADR 0003). Every folder row takes a
/// drop; a drop between rows lands in the folder holding them. Folders of the
/// Locations tree can be dragged. A favorite is dragged only within Favorites,
/// because anywhere else it would move the folder itself, not the shortcut to
/// it (ADR 0050).
extension SidebarCoordinator {
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (
        any NSPasteboardWriting
    )? {
        guard let node = item as? SidebarNode, let folder = node.item else { return nil }
        if isFavoriteRow(node, in: outlineView) {
            let favorite = NSPasteboardItem()
            favorite.setString(folder.id.rawValue, forType: Self.favoriteDragType)
            return favorite
        }
        return URL(fileURLWithPath: folder.id.rawValue) as NSURL
    }

    func outlineView(
        _ outlineView: NSOutlineView, validateDrop info: any NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        springLoading.hover(item as? SidebarNode) { [weak outlineView] in
            outlineView?.expandItem($0)
        }
        if let operation = validateFavoriteDrop(info, in: outlineView, item: item, index: index) {
            return operation
        }
        guard let node = item as? SidebarNode, let folder = node.item else {
            DropRouting.finish()
            return []
        }
        if index != NSOutlineViewDropOnItemIndex {
            outlineView.setDropItem(node, dropChildIndex: NSOutlineViewDropOnItemIndex)
        }
        return DropRouting.operation(of: info, over: folder)
    }

    func outlineView(
        _ outlineView: NSOutlineView, acceptDrop info: any NSDraggingInfo, item: Any?,
        childIndex index: Int
    ) -> Bool {
        if acceptFavoriteDrop(info, item: item, index: index) { return true }
        return DropRouting.perform(
            info.draggingPasteboard, on: (item as? SidebarNode)?.item, with: drop)
    }

    func outlineView(
        _ outlineView: NSOutlineView, draggingSession session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        DropRouting.finish()
    }
}
