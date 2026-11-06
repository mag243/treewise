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
    /// Where the pattern's fields sit in `text`, marked until the user types (ADR 0064).
    let marks: [NSRange]
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
final class GapSelectingField: NSTextField {
    /// Treewise's yellow, from its icon, under a field of the pattern in the name; see
    /// through, so the text stays readable in light and dark.
    private static let markColor = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(
            srgbRed: markRed, green: markGreen, blue: markBlue,
            alpha: isDark ? markDarkOpacity : markLightOpacity)
    }
    private static let markRed = 247.0 / 255, markGreen = 200.0 / 255, markBlue = 67.0 / 255
    private static let markLightOpacity = 0.45, markDarkOpacity = 0.35
    private var marks: [NSRange] = []

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            showMarks()
            selectGap()
        }
        return became
    }

    /// Marks these ranges of the text; none clears them.
    func mark(_ ranges: [NSRange]) {
        guard ranges != marks else { return }
        marks = ranges
        showMarks()
    }

    /// Shows the marks on the text, or in the editor while editing, where they are drawn
    /// over the text without becoming part of it.
    private func showMarks() {
        let whole = NSRange(location: 0, length: (stringValue as NSString).length)
        let fitting = marks.filter { NSMaxRange($0) <= whole.length }
        if let editor = currentEditor() as? NSTextView, let layout = editor.layoutManager {
            layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
            for range in fitting {
                layout.addTemporaryAttribute(
                    .backgroundColor, value: Self.markColor, forCharacterRange: range)
            }
            return
        }
        let text = NSMutableAttributedString(
            string: stringValue, attributes: font.map { [.font: $0] } ?? [:])
        for range in fitting {
            text.addAttribute(.backgroundColor, value: Self.markColor, range: range)
        }
        attributedStringValue = text
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
