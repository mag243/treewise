import AppKit
import TreewiseCore
import TreewiseUI

/// Dragging from and onto the list (ADR 0003). Rows go on the drag pasteboard
/// as file URLs, so Finder and other apps take them too. A drop on a folder row
/// lands in that folder; on a file or on empty space, in the folder the list
/// shows, which AppKit then outlines as a whole.
extension FileTableCoordinator {
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (
        any NSPasteboardWriting
    )? {
        guard items.indices.contains(row) else { return nil }
        return items[row].id.diskURL as NSURL?
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        let row = folderRow(row, dropOperation)
        tableView.setDropRow(row ?? -1, dropOperation: .on)
        return DropRouting.operation(of: info, over: row.map { items[$0] } ?? folder)
    }

    func tableView(
        _ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        let target = folderRow(row, dropOperation).map { items[$0] } ?? folder
        return DropRouting.perform(info.draggingPasteboard, on: target, with: actions?.drop)
    }

    func tableView(
        _ tableView: NSTableView, draggingSession session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        DropRouting.finish()
    }

    /// The row a drop lands in, when it is on a folder; `nil` for the list's folder.
    private func folderRow(_ row: Int, _ dropOperation: NSTableView.DropOperation) -> Int? {
        guard dropOperation == .on, items.indices.contains(row), items[row].isContainer else {
            return nil
        }
        return row
    }
}
