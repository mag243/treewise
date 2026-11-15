import AppKit
import TreewiseCore

/// Renaming in the list, through its `NameFieldRenamer`.
extension FileTableCoordinator {
    func beginRename(row: Int, suggests: Bool = false) {
        guard let table, items.indices.contains(row) else { return }
        table.scrollRowToVisible(row)
        guard items[row].canBeRenamedOrTrashed,
            let cell = table.view(atColumn: 0, row: row, makeIfNecessary: true) as? NSTableCellView,
            let field = cell.textField
        else { return }
        renamer.begin(items[row], in: field, suggests: suggests)
    }
}
