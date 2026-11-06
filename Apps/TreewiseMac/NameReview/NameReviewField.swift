import AppKit
import SwiftUI
import TreewiseCore

/// The name of the selected row, as text to edit. Starting on a gap selects the gap.
/// Until the user types, ↑ and ↓ step to the previous and next option and put the cursor
/// at the end of its name (ADR 0064); after that, and with one option, they do what they
/// always do.
struct NameReviewField: NSViewRepresentable {
    let text: String
    let placeholder: String
    let onChange: (String) -> Void
    let onFinish: () -> Void
    /// What the pattern's fields filled in `text`, in their colours, until the user types
    /// (ADR 0064).
    let marks: [ColoredRange]
    /// Whether the field is to take the focus, as asked by a double click on its row.
    let startsEditing: Bool
    let onStartedEditing: () -> Void
    /// Steps to another option and gives its name; nil when the row has one option.
    let onStep: ((StepDirection) -> String?)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = GapSelectingField(string: text)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingMiddle
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = placeholder
        if field.currentEditor() == nil, field.stringValue != text { field.stringValue = text }
        (field as? GapSelectingField)?.mark(context.coordinator.hasTyped ? [] : marks)
        if startsEditing {
            // After this update, so the field is in its window when it takes the focus.
            Task { @MainActor in
                field.window?.makeFirstResponder(field)
                onStartedEditing()
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NameReviewField
        /// Whether the user typed since the field got the focus, so the text is their own.
        private(set) var hasTyped = false

        init(_ parent: NameReviewField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField {
                hasTyped = true
                (field as? GapSelectingField)?.mark([])
                parent.onChange(field.stringValue)
            }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            hasTyped = false
            parent.onFinish()
        }

        func control(
            _ control: NSControl, textView: NSTextView, doCommandBy selector: Selector
        ) -> Bool {
            let direction: StepDirection
            switch selector {
            case #selector(NSResponder.moveUp(_:)): direction = .previous
            case #selector(NSResponder.moveDown(_:)): direction = .next
            default: return false
            }
            guard !hasTyped, let onStep = parent.onStep, let field = control as? NSTextField,
                let name = onStep(direction)
            else { return false }
            // Set on the field, not typed into the editor, so it is no edit of the user's.
            field.stringValue = name
            // The cursor goes before the extension: a selection would be replaced by the
            // first key, and the marks already show what changes.
            let stem = ProposedName.stem(of: name) as NSString
            textView.selectedRange = NSRange(location: stem.length, length: 0)
            return true
        }
    }
}

/// A field that selects a name's gap as soon as it gets the focus, by a click or by Tab,
/// so what is typed replaces the gap.
final class GapSelectingField: MarkingTextField {
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { selectGap() }
        return became
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // A click places the cursor where it lands; the gap is chosen after that.
        selectGap()
    }

    private func selectGap() {
        guard let range = stringValue.range(of: NameTemplate.gap) else { return }
        currentEditor()?.selectedRange = NSRange(range, in: stringValue)
    }
}
