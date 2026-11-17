import AppKit
import TreewiseCore
import TreewiseUI

/// The colours of a pattern's fields, the same in the pattern and in the name they filled
/// (ADR 0064), drawn from the palette both apps share (`NameColors`, ADR 0130).
@MainActor
enum FieldColors {
    /// The colour of the field at this place among a pattern's fields.
    static func color(_ index: Int) -> NSColor {
        let base = hue(NameColors.fieldHue(index))
        return NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return base.withAlphaComponent(
                isDark ? NameColors.fieldOpacity.dark : NameColors.fieldOpacity.light)
        }
    }

    /// The fields in a pattern's text, each in its colour.
    static func marks(inPattern text: String) -> [ColoredRange] {
        NameMark.inPattern(text).map {
            ColoredRange(range: NSRange($0.range, in: text), tint: $0.tint)
        }
    }

    private static func hue(_ hue: NameColors.Hue) -> NSColor {
        switch hue {
        case .treewiseYellow:
            let yellow = NameColors.treewiseYellow
            return NSColor(srgbRed: yellow.red, green: yellow.green, blue: yellow.blue, alpha: 1)
        case .green: return .systemGreen
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .teal: return .systemTeal
        case .brown: return .systemBrown
        }
    }
}

/// A stretch of a field's text in the colour of a pattern's field, or of a gap or a date
/// to look at, as the other rows of the review show them.
struct ColoredRange: Equatable {
    /// What a stretch is coloured for.
    typealias Tint = NameMark.Tint

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
        case .gap: NSColor.controlAccentColor.withAlphaComponent(NameColors.lookOpacity)
        case .dateToCheck: NSColor.systemOrange.withAlphaComponent(NameColors.lookOpacity)
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
