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
