import AppKit
import TreewiseCore

/// A cell of the Git column: the state's word in the colour of its badge (ADR 0149), white
/// on a selected row of the active pane, as a selected row's other texts are.
final class GitStateCell: NSTableCellView {
    /// The state the cell shows; its word is set by the list.
    var state: GitItemState? {
        didSet { colour() }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { colour() }
    }

    private func colour() {
        textField?.textColor =
            backgroundStyle == .emphasized
            ? .alternateSelectedControlTextColor
            : state.map(GitBadgeView.colour(of:)) ?? .labelColor
    }
}
