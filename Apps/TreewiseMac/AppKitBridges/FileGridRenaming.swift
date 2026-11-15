import AppKit
import TreewiseCore

/// Renaming in the icon view, through its `NameFieldRenamer`, as in the list.
extension FileGridCoordinator {
    /// Scrolls to a tile and lays out what comes into view, because the grid
    /// has no tile for an item out of view. A tile in view stays where it is.
    func reveal(index: Int) {
        guard let grid, items.indices.contains(index) else { return }
        grid.layoutSubtreeIfNeeded()
        let path = IndexPath(item: index, section: 0)
        guard let frame = grid.layoutAttributesForItem(at: path)?.frame else { return }
        grid.scrollToVisible(frame)
        grid.layoutSubtreeIfNeeded()
    }

    func beginRename(index: Int, suggests: Bool = false) {
        reveal(index: index)
        guard let grid, items.indices.contains(index), items[index].canBeRenamedOrTrashed,
            let tile = grid.item(at: IndexPath(item: index, section: 0)) as? FileGridItem,
            let field = tile.textField
        else { return }
        renamer.begin(items[index], in: field, suggests: suggests)
    }
}
