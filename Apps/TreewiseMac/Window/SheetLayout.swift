import AppKit

/// The layout Treewise's sheets and the panels inside its overview share: the room around
/// their contents, the room between them, and the row of buttons at the foot.
@MainActor
enum SheetLayout {
    /// The room around a sheet's contents.
    static let margin: CGFloat = 20
    /// The room between a sheet's parts.
    static let spacing: CGFloat = 12
    static let insets = NSEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)

    /// A column of `views`, with the margin around it and the spacing between them.
    static func column(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.edgeInsets = insets
        return stack
    }

    /// The buttons at a sheet's foot: `leading` at the start, then Cancel, on Escape, and
    /// the default button, on Return, at the end, as macOS places them.
    static func buttonRow(leading: [NSView] = [], cancel: NSButton?, confirm: NSButton)
        -> NSStackView
    {
        cancel?.keyEquivalent = "\u{1b}"
        confirm.keyEquivalent = "\r"
        let row = NSStackView()
        row.setViews(leading, in: .leading)
        row.setViews([cancel, confirm].compactMap { $0 }, in: .trailing)
        return row
    }
}
