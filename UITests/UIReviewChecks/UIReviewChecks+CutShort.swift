import XCTest

#if canImport(UIKit)
    import UIKit

    /// A text of one line cut short with `…` anywhere on the screen, as a picker's chosen
    /// value beside a long label on the iPhone (ADR 0132). iOS reports the whole text with
    /// the frame it was given, so a text that needs more than its frame was cut.
    extension UIReviewChecks {
        /// A line's height to the size of the system font it is set in, as SwiftUI lays out
        /// its text styles.
        static let lineToFontSize: CGFloat = 1.19
        /// The sizes a single line of text is set in on these screens; a taller frame holds
        /// more lines or a large title, which this check leaves alone.
        static let oneLineFontSizes: ClosedRange<CGFloat> = 10...22
        /// How much wider than its frame a text may measure before it counts as cut short: a
        /// text shown whole measures up to 3 points over its frame, as frames are rounded and
        /// the system's tracking is not measured.
        static let cutShortSlack: CGFloat = 3.5

        /// The texts of one line that need more room than their frame gives them.
        static func cutShort(_ placed: [Placed]) -> [UIReviewFinding] {
            placed.compactMap { item in
                let text = item.snapshot
                guard text.elementType == .staticText, !text.label.isEmpty else { return nil }
                let size = text.frame.height / lineToFontSize
                guard oneLineFontSizes.contains(size) else { return nil }
                let font = UIFont.systemFont(ofSize: size)
                let needs = (text.label as NSString).size(withAttributes: [.font: font]).width
                guard needs > text.frame.width + cutShortSlack else { return nil }
                return finding(
                    "cutShort", text,
                    "needs \(Int(needs)) in \(Int(text.frame.width)) at \(Int(size)) points")
            }
        }
    }
#endif
