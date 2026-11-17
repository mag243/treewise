import SwiftUI
import TreewiseUI
import UIKit

/// The shared palette of a name's coloured parts (`NameColors`, ADR 0130) in UIKit's and
/// SwiftUI's colours, light and dark as on the Mac.
@MainActor
enum NameMarkColors {
    static func color(_ tint: NameMark.Tint) -> UIColor {
        switch tint {
        case .field(let index):
            let base = hue(NameColors.fieldHue(index))
            return UIColor { traits in
                base.withAlphaComponent(
                    traits.userInterfaceStyle == .dark
                        ? NameColors.fieldOpacity.dark : NameColors.fieldOpacity.light)
            }
        case .gap: return UIColor.tintColor.withAlphaComponent(NameColors.lookOpacity)
        case .dateToCheck: return UIColor.systemOrange.withAlphaComponent(NameColors.lookOpacity)
        }
    }

    /// `text` with `marks` as backgrounds, in `font` and `textColor`.
    static func attributed(
        _ text: String, marks: [NameMark], font: UIFont, textColor: UIColor = .label,
        isStruckThrough: Bool = false
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        if isStruckThrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        let attributed = NSMutableAttributedString(string: text, attributes: attributes)
        for mark in marks
        where mark.range.lowerBound >= text.startIndex && mark.range.upperBound <= text.endIndex {
            attributed.addAttribute(
                .backgroundColor, value: color(mark.tint), range: NSRange(mark.range, in: text))
        }
        return attributed
    }

    /// `text` with `marks` as backgrounds, for a SwiftUI `Text`.
    static func text(_ text: String, marks: [NameMark]) -> AttributedString {
        var attributed = AttributedString(text)
        for mark in marks {
            guard let range = Range(NSRange(mark.range, in: text), in: attributed) else { continue }
            attributed[range].backgroundColor = Color(uiColor: color(mark.tint))
        }
        return attributed
    }

    private static func hue(_ hue: NameColors.Hue) -> UIColor {
        switch hue {
        case .treewiseYellow:
            let yellow = NameColors.treewiseYellow
            return UIColor(red: yellow.red, green: yellow.green, blue: yellow.blue, alpha: 1)
        case .green: return .systemGreen
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .teal: return .systemTeal
        case .brown: return .systemBrown
        }
    }
}
