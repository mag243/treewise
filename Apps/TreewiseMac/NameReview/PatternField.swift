import AppKit
import SwiftUI
import TreewiseCore

/// What to insert into a pattern, at the place of the cursor. A new id asks again.
struct PatternInsertion: Equatable {
    let id = UUID()
    let token: String
}

/// The field for a pattern. A field clicked in the list of fields lands where the cursor
/// was, or replaces what was selected, not at the end.
struct PatternField: NSViewRepresentable {
    @Binding var text: String
    let insertion: PatternInsertion?
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SelectionKeepingField {
        let field = SelectionKeepingField(string: text)
        field.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        field.delegate = context.coordinator
        field.lastSelection = NSRange(location: (text as NSString).length, length: 0)
        return field
    }

    func updateNSView(_ field: SelectionKeepingField, context: Context) {
        context.coordinator.parent = self
        if field.currentEditor() == nil, field.stringValue != text { field.stringValue = text }
        // Each field in its colour, as the name of the selected row shows what it filled.
        field.mark(FieldColors.marks(inPattern: field.stringValue))
        guard let insertion, insertion != context.coordinator.handled else { return }
        context.coordinator.handled = insertion
        field.insert(insertion.token)
        // A view's state may not change while SwiftUI updates it.
        let inserted = field.stringValue
        let binding = $text
        DispatchQueue.main.async { binding.wrappedValue = inserted }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PatternField
        var handled: PatternInsertion?

        init(_ parent: PatternField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? SelectionKeepingField {
                field.mark(FieldColors.marks(inPattern: field.stringValue))
                parent.text = field.stringValue
            }
        }

        func control(
            _ control: NSControl, textView: NSTextView, doCommandBy selector: Selector
        ) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.onSubmit()
            return true
        }
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
