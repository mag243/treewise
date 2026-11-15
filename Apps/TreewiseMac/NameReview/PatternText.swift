import AppKit
import TreewiseCore
import TreewiseUI

/// A pattern's text as the overview shows it: small and monospaced, each field in its colour,
/// as the name it made shows them.
@MainActor
enum PatternText {
    static func coloured(_ pattern: String) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: pattern,
            attributes: [
                .font: NSFont.monospacedSystemFont(
                    ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize,
                    weight: .regular)
            ])
        for mark in FieldColors.marks(inPattern: pattern) {
            text.addAttribute(.backgroundColor, value: mark.color, range: mark.range)
        }
        return text
    }
}
