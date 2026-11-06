import AppKit
import TreewiseCore

/// Renaming in the list: the name cell becomes editable with the full name,
/// the part before its extension selected, as in Finder, also when the list
/// hides extensions (ADR 0023). Return commits, Escape cancels, and ⌥Esc or F5
/// asks the add-ons for proposals (ADR 0066).
extension FileTableCoordinator: NSTextFieldDelegate {
    func beginRename(row: Int, suggests: Bool = false) {
        guard let table, items.indices.contains(row), items[row].canBeRenamedOrTrashed,
            let cell = table.view(atColumn: 0, row: row, makeIfNecessary: true) as? NSTableCellView,
            let field = cell.textField
        else { return }
        renaming = items[row]
        field.isEditable = true
        field.delegate = self
        field.stringValue = items[row].name
        table.window?.makeFirstResponder(field)
        let name = items[row].name as NSString
        let base =
            items[row].kind == .folder
            ? name.length : (name.deletingPathExtension as NSString).length
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: base)
        if suggests { actions?.suggestName(items[row], field) }
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
        control.window?.makeFirstResponder(table)
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        field.isEditable = false
        defer { renaming = nil }
        guard let item = renaming else { return }
        let name = field.stringValue
        if name != item.name {
            actions?.rename(item, name)
        } else {
            field.stringValue = shownName(of: item)
        }
        table?.window?.makeFirstResponder(table)
    }
}
