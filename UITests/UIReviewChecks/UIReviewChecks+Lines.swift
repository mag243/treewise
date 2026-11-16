import XCTest

#if canImport(AppKit)
    import AppKit
#else
    import UIKit
#endif

/// Running text that reads poorly: one line across much of the screen (ADR 0115).
extension UIReviewChecks {
    /// The widest a line of running text may be: about 80 characters of the body font, past
    /// which the eye loses the next line.
    static let readableLine: CGFloat = 720
    /// How many words make a text running text, not a name or a path.
    static let runningWords = 8
    /// How much taller than one line of the body font a text may be and still be one line.
    static let oneLineSlack: CGFloat = 1.5

    /// A text of several words set on one line wider than `readableLine`: it should wrap in
    /// a narrower column.
    static func overlongLines(_ placed: [Placed]) -> [UIReviewFinding] {
        // A line's height from the font's own measures, which both platforms' fonts have.
        let line = listFont.ascender - listFont.descender + listFont.leading
        let oneLine = line * oneLineSlack
        return placed.compactMap { item in
            let text = item.snapshot
            guard text.elementType == .staticText, text.frame.width > readableLine,
                text.frame.height <= oneLine,
                text.label.split(separator: " ").count >= runningWords
            else { return nil }
            return finding(
                "overlongLine", text,
                "one line \(text.frame.width) wide; running text reads best within \(readableLine)"
            )
        }
    }
}
