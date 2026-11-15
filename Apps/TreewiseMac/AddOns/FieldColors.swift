import AppKit
import TreewiseCore

/// The colours of a pattern's fields, the same in the pattern and in the name they filled
/// (ADR 0064): Treewise's yellow first, then green, purple, pink, teal and brown, see
/// through so the text stays readable. Blue and orange are left out, as they mean a gap
/// and a date to check.
@MainActor
enum FieldColors {
    private static let lightOpacity = 0.45
    private static let darkOpacity = 0.35
    /// The yellow of Treewise's icon.
    private static let yellow = NSColor(
        srgbRed: 247.0 / 255, green: 200.0 / 255, blue: 67.0 / 255, alpha: 1)
    private static let series: [NSColor] = [
        yellow, .systemGreen, .systemPurple, .systemPink, .systemTeal, .systemBrown,
    ]

    /// The colour of the field at this place among a pattern's fields.
    static func color(_ index: Int) -> NSColor {
        let base = series[index % series.count]
        return NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return base.withAlphaComponent(isDark ? darkOpacity : lightOpacity)
        }
    }

    /// The fields in a pattern's text, each in its colour.
    static func marks(inPattern text: String) -> [ColoredRange] {
        let order = NameTemplate.fieldOrder(in: text)
        return NameTemplate.fieldTokens(in: text).map { token in
            ColoredRange(
                range: NSRange(token.range, in: text),
                colorIndex: order.firstIndex(of: token.key) ?? 0)
        }
    }
}

/// A stretch of a field's text in the colour of a pattern's field, or of a gap or a date
/// to look at, as the other rows of the review show them.
struct ColoredRange: Equatable {
    /// What a stretch is coloured for.
    enum Tint: Equatable {
        /// The field at this place in the pattern's order (ADR 0064).
        case field(Int)
        /// A gap for the user to fill in.
        case gap
        /// A date that comes from the file, to be checked (ADR 0058).
        case dateToCheck
    }

    /// How see-through a gap's and a date's colour is, as in the other rows.
    private static let lookOpacity: CGFloat = 0.25

    let range: NSRange
    let tint: Tint

    init(range: NSRange, colorIndex: Int) {
        self.range = range
        tint = .field(colorIndex)
    }

    init(range: NSRange, tint: Tint) {
        self.range = range
        self.tint = tint
    }

    @MainActor var color: NSColor {
        switch tint {
        case .field(let index): FieldColors.color(index)
        case .gap: NSColor.controlAccentColor.withAlphaComponent(Self.lookOpacity)
        case .dateToCheck: NSColor.systemOrange.withAlphaComponent(Self.lookOpacity)
        }
    }
}

/// A text field that colours stretches of its text, also while it is edited, where the
/// colours are drawn over the text without becoming part of it.
class MarkingTextField: NSTextField {
    private var marks: [ColoredRange] = []

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { showMarks() }
        return became
    }

    /// Colours these stretches; none clears them.
    func mark(_ ranges: [ColoredRange]) {
        guard ranges != marks else { return }
        marks = ranges
        showMarks()
    }

    private func showMarks() {
        let whole = NSRange(location: 0, length: (stringValue as NSString).length)
        let fitting = marks.filter { NSMaxRange($0.range) <= whole.length }
        if let editor = currentEditor() as? NSTextView, let layout = editor.layoutManager {
            layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
            for mark in fitting {
                layout.addTemporaryAttribute(
                    .backgroundColor, value: mark.color, forCharacterRange: mark.range)
            }
            return
        }
        let text = NSMutableAttributedString(
            string: stringValue, attributes: font.map { [.font: $0] } ?? [:])
        for mark in fitting {
            text.addAttribute(.backgroundColor, value: mark.color, range: mark.range)
        }
        attributedStringValue = text
    }
}
