import SwiftUI
import TreewiseUI

/// The measures and colours of Treewise's own file icons (ADR 0151), as parts of the
/// icon's side.
enum FilePageStyle {
    /// A row's icon side at the default text size, in points.
    static let side: CGFloat = 22
    static let widthRatio: CGFloat = 0.8
    static let foldRatio: CGFloat = 0.25
    static let lineRatio: CGFloat = 0.06
    /// The band of a page with a band, and where the label of a filled page sits.
    static let bandRatio: CGFloat = 0.42
    static let labelRatio: CGFloat = 0.36
    static let filledLabelRatio: CGFloat = 0.34
    /// The label of a neutral page: its height, text, side padding, corner and place.
    static let tagRatio: CGFloat = 0.36
    static let tagLabelRatio: CGFloat = 0.3
    static let tagPaddingRatio: CGFloat = 0.04
    /// The label's width per letter and for its two ends.
    static let tagLetterRatio: CGFloat = 0.24
    static let tagEndsRatio: CGFloat = 0.2
    static let tagCorner: CGFloat = 0.07
    static let tagBottomRatio: CGFloat = 0.12
    /// The bar a neutral page shows for a file without a label.
    static let barRatio: CGFloat = 0.12
    static let barInsetRatio: CGFloat = 0.22
    static let tintOpacity = 0.12
    static let flapOpacity = 0.45
    /// How far a long label may shrink to fit.
    static let labelShrink: CGFloat = 0.6

    /// The kind's colour, one of the system's, so dark mode follows.
    static func colour(of kind: FileBadge.Kind) -> Color {
        switch kind {
        case .pdf: .red
        case .document: .blue
        case .spreadsheet: .green
        case .presentation: .orange
        case .image: .purple
        case .movie: .teal
        case .audio: .pink
        case .archive: .brown
        case .code: .indigo
        case .text, .other: .gray
        }
    }
}
