import AppKit

/// The colours and opacities Treewise's views share, so a problem or a cut item looks the
/// same everywhere.
@MainActor
enum Tint {
    /// The fill of a surface in the accent colour, such as the template bar or a badge.
    static let accentFill: CGFloat = 0.12
    /// The opacity of a cut item until it is pasted.
    static let cut: CGFloat = 0.5
    /// The colour of a problem's text and icon: one that asks for attention without
    /// meaning that something broke.
    static let problem = NSColor.systemOrange
}
