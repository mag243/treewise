import AppKit
import TreewiseCore

/// Runs the field for a pattern: each field of the pattern in its colour, and
/// what is typed, Return and leaving the field reported to closures. A token
/// clicked in the list of fields lands where the cursor was, or replaces what
/// was selected, not at the end.
@MainActor
final class PatternFieldDriver: NSObject, NSTextFieldDelegate {
    let field: SelectionKeepingField
    /// Called with the text after each change.
    var onChange: (String) -> Void = { _ in }
    var onSubmit: () -> Void = {}
    /// Called when the field loses the focus.
    var onEndEditing: () -> Void = {}

    init(text: String) {
        field = SelectionKeepingField(string: text)
        super.init()
        field.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        field.delegate = self
        field.lastSelection = NSRange(location: (text as NSString).length, length: 0)
        field.mark(FieldColors.marks(inPattern: text))
    }

    /// Shows `text`, unless the field is being typed in.
    func show(_ text: String) {
        guard field.currentEditor() == nil, field.stringValue != text else { return }
        field.stringValue = text
        field.mark(FieldColors.marks(inPattern: text))
    }

    /// Puts `token` in place of the remembered selection.
    func insert(_ token: String) {
        field.insert(token)
        field.mark(FieldColors.marks(inPattern: field.stringValue))
        onChange(field.stringValue)
    }

    func controlTextDidChange(_ notification: Notification) {
        field.mark(FieldColors.marks(inPattern: field.stringValue))
        onChange(field.stringValue)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        onEndEditing()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector)
        -> Bool
    {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        onSubmit()
        return true
    }
}

/// A text field that remembers its selection after it loses the focus, as it does when
/// a button beside it is clicked.
final class SelectionKeepingField: MarkingTextField {
    var lastSelection = NSRange(location: 0, length: 0)

    @objc func textViewDidChangeSelection(_ notification: Notification) {
        if let editor = notification.object as? NSTextView {
            lastSelection = editor.selectedRange()
        }
    }

    /// Puts text in place of the remembered selection, and the cursor after it.
    func insert(_ token: String) {
        let current = stringValue as NSString
        let range = NSIntersectionRange(lastSelection, NSRange(location: 0, length: current.length))
        let place =
            range.length == 0 && lastSelection.location > current.length
            ? NSRange(location: current.length, length: 0) : range
        stringValue = current.replacingCharacters(in: place, with: token)
        let after = NSRange(location: place.location + (token as NSString).length, length: 0)
        lastSelection = after
        window?.makeFirstResponder(self)
        currentEditor()?.selectedRange = after
    }
}
