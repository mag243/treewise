import AppKit
import TreewiseCore

/// Renaming in a list or the icon view: the name's field becomes editable with the full
/// name, the part before its extension selected, as in Finder, also when the list hides
/// extensions (ADR 0023, ADR 0109). Return commits, Escape cancels, and ⌥Esc or F5 asks
/// the add-ons for proposals (ADR 0066). The list and the icon view each have one.
@MainActor
final class NameFieldRenamer: NSObject, NameFieldEditing {
    /// The item being renamed, while its field is edited.
    private(set) var renaming: FileItem?
    private let actions: () -> FileTableActions?
    private let shownName: (FileItem) -> String
    /// The view that has the focus back when the rename ends.
    private let home: () -> NSView?
    /// Whether the field stops being selectable when the rename ends, as a tile's name.
    private let unselectableAfter: Bool

    init(
        actions: @escaping () -> FileTableActions?, shownName: @escaping (FileItem) -> String,
        home: @escaping () -> NSView?, unselectableAfter: Bool = false
    ) {
        self.actions = actions
        self.shownName = shownName
        self.home = home
        self.unselectableAfter = unselectableAfter
    }

    /// Starts renaming `item` in `field`; with `suggests`, the add-ons' proposals show.
    func begin(_ item: FileItem, in field: NSTextField, suggests: Bool) {
        renaming = item
        field.isEditable = true
        field.delegate = self
        field.stringValue = item.name
        field.window?.makeFirstResponder(field)
        // The stem is selected, so typing keeps the extension (ADR 0109).
        let stem = FileName.stem(of: item.name, kind: item.kind) as NSString
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: stem.length)
        NameSpelling.check(field, actions()?.checksSpelling() ?? false)
        if suggests { actions()?.suggestName(item, field) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        // ⌥Esc and F5, the keys macOS completes text with, ask for proposals.
        if commandSelector == #selector(NSTextView.complete(_:)), let item = renaming,
            let field = control as? NSTextField
        {
            actions()?.suggestName(item, field)
            return true
        }
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)), let item = renaming
        else { return false }
        (control as? NSTextField)?.stringValue = shownName(item)
        renaming = nil
        control.window?.makeFirstResponder(home())
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        NameSpelling.stop(after: notification)
        guard let field = notification.object as? NSTextField else { return }
        field.isEditable = false
        if unselectableAfter { field.isSelectable = false }
        defer { renaming = nil }
        guard let item = renaming else { return }
        let name = field.stringValue
        if name != item.name {
            actions()?.rename(item, name)
        } else {
            field.stringValue = shownName(item)
        }
        let home = home()
        home?.window?.makeFirstResponder(home)
    }
}
