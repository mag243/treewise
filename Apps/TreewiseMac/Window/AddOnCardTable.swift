import AppKit

/// The list of add-on cards, which starts a drag only where `canDrag` says, as on a card's
/// header and not on its switch or its body (ADR 0106).
@MainActor
final class AddOnCardTable: NSTableView {
    /// Whether a drag may start in `row` at a point in the table's coordinates.
    var canDrag: (Int, NSPoint) -> Bool = { _, _ in true }

    override func canDragRows(with rowIndexes: IndexSet, at mouseDownPoint: NSPoint) -> Bool {
        let row = row(at: mouseDownPoint)
        guard row >= 0, canDrag(row, mouseDownPoint) else { return false }
        return super.canDragRows(with: rowIndexes, at: mouseDownPoint)
    }
}
