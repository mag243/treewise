import AppKit
import TreewiseCore

/// The name of the selected row, as text to edit. A name wider than the row goes on to a
/// next line, as the original name above it does, so the whole name is read before it is
/// approved. Starting on a gap selects the gap.
/// Until the user types, ↑ and ↓ step to the previous and next option and put the cursor
/// at the end of its name (ADR 0064); after that, and with one option, they do what they
/// always do.
@MainActor
final class NameReviewField: NSObject, NSTextFieldDelegate {
    let field = GapSelectingField(string: "")
    var onChange: (String) -> Void = { _ in }
    var onFinish: () -> Void = {}
    /// Steps to another option and gives its name; nil when the row has one option.
    var onStep: ((StepDirection) -> String?)?
    /// Whether the user typed since the field got the focus, so the text is their own.
    private(set) var hasTyped = false
    private var marks: [ColoredRange] = []
    private var lookMarks: [ColoredRange] = []

    override init() {
        super.init()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.delegate = self
    }

    /// Shows `text`, unless it is being typed in, with what the pattern's fields filled in
    /// their colours until the user types (ADR 0064), and a gap and a date to check, also
    /// once the user types, over them.
    func show(
        _ text: String, placeholder: String, marks: [ColoredRange], lookMarks: [ColoredRange]
    ) {
        field.placeholderString = placeholder
        if field.currentEditor() == nil, field.stringValue != text { field.stringValue = text }
        self.marks = marks
        self.lookMarks = lookMarks
        field.mark((hasTyped ? [] : marks) + lookMarks)
    }

    /// Gives the field the keyboard focus.
    func startEditing() {
        field.window?.makeFirstResponder(field)
    }

    func controlTextDidChange(_ notification: Notification) {
        hasTyped = true
        field.mark(lookMarks)
        onChange(field.stringValue)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        hasTyped = false
        onFinish()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector)
        -> Bool
    {
        let direction: StepDirection
        switch selector {
        case #selector(NSResponder.moveUp(_:)): direction = .previous
        case #selector(NSResponder.moveDown(_:)): direction = .next
        default: return false
        }
        guard !hasTyped, let onStep, let name = onStep(direction) else { return false }
        // Set on the field, not typed into the editor, so it is no edit of the user's.
        field.stringValue = name
        // The cursor goes before the extension: a selection would be replaced by the
        // first key, and the marks already show what changes.
        let stem = ProposedName.stem(of: name) as NSString
        textView.selectedRange = NSRange(location: stem.length, length: 0)
        return true
    }
}

/// A field that selects a name's gap as soon as it gets the focus, by a click or by Tab,
/// so what is typed replaces the gap.
final class GapSelectingField: MarkingTextField {
    /// As high as the name needs at the width it wraps at, which an editable field does
    /// not work out by itself.
    override var intrinsicContentSize: NSSize {
        guard preferredMaxLayoutWidth > 0, let cell else { return super.intrinsicContentSize }
        let bounds = NSRect(
            x: 0, y: 0, width: preferredMaxLayoutWidth, height: .greatestFiniteMagnitude)
        return NSSize(
            width: NSView.noIntrinsicMetric, height: ceil(cell.cellSize(forBounds: bounds).height))
    }

    override var preferredMaxLayoutWidth: CGFloat {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var stringValue: String {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        invalidateIntrinsicContentSize()
    }

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
