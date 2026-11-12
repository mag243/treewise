import AppKit
import TreewiseCore

/// Renaming in the icon view, as in the list: the tile's name becomes
/// editable with the full name, the part before its extension selected
/// (ADR 0023). Return commits, Escape cancels, and ⌥Esc or F5 asks the add-ons
/// for proposals (ADR 0066).
extension FileGridCoordinator: NameFieldEditing {
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
        let item = items[index]
        renaming = item
        field.isEditable = true
        field.delegate = self
        field.stringValue = item.name
        grid.window?.makeFirstResponder(field)
        let name = item.name as NSString
        let base =
            item.kind == .folder ? name.length : (name.deletingPathExtension as NSString).length
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: base)
        NameSpelling.check(field, actions?.checksSpelling() ?? false)
        if suggests { actions?.suggestName(item, field) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        // ⌥Esc and F5, the keys macOS completes text with, ask for proposals.
        if commandSelector == #selector(NSTextView.complete(_:)), let item = renaming,
            let field = control as? NSTextField
        {
            actions?.suggestName(item, field)
            return true
        }
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)), let item = renaming
        else { return false }
        (control as? NSTextField)?.stringValue = shownName(of: item)
        renaming = nil
        control.window?.makeFirstResponder(grid)
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        NameSpelling.stop(after: notification)
        guard let field = notification.object as? NSTextField else { return }
        field.isEditable = false
        field.isSelectable = false
        defer { renaming = nil }
        guard let item = renaming else { return }
        let name = field.stringValue
        if name != item.name {
            actions?.rename(item, name)
        } else {
            field.stringValue = shownName(of: item)
        }
        grid?.window?.makeFirstResponder(grid)
    }
}
