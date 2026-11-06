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

/// A stretch of a field's text in the colour of a pattern's field.
struct ColoredRange: Equatable {
    let range: NSRange
    let colorIndex: Int
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
                    .backgroundColor, value: FieldColors.color(mark.colorIndex),
                    forCharacterRange: mark.range)
            }
            return
        }
        let text = NSMutableAttributedString(
            string: stringValue, attributes: font.map { [.font: $0] } ?? [:])
        for mark in fitting {
            text.addAttribute(
                .backgroundColor, value: FieldColors.color(mark.colorIndex), range: mark.range)
        }
        attributedStringValue = text
    }
}
