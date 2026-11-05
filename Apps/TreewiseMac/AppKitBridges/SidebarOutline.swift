import AppKit

/// The sidebar's outline view; it hides the drag badge when a drag leaves it,
/// reports the end of a drag over it, and asks for a row's context menu.
final class SidebarOutline: NSOutlineView {
    /// Called when a drag leaves the sidebar, drops or ends.
    var dragEnded: (() -> Void)?
    /// The context menu of a row, or `nil` for none (ADR 0044, ADR 0050).
    var rowMenu: ((SidebarNode) -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        guard let node = item(atRow: row) as? SidebarNode else { return nil }
        return rowMenu?(node)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        super.draggingExited(sender)
        DropRouting.finish()
        dragEnded?()
    }

    override func draggingEnded(_ sender: any NSDraggingInfo) {
        super.draggingEnded(sender)
        dragEnded?()
    }
}
