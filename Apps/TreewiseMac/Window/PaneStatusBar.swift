import AppKit
import TreewiseCore
import TreewiseUI

/// The status bar as in Explorer (M5b): the counts at the left, the buttons
/// that show the folder as a list or as icons at the right.
@MainActor
final class PaneStatusBar: NSStackView {
    private static let barPadding: CGFloat = 4
    private static let sidePadding: CGFloat = 10
    private static let fontSize: CGFloat = 11
    private static let modes: [ViewMode] = [.list, .icons]

    private let counts = NSTextField(labelWithString: "")
    private let viewButtons: NSSegmentedControl
    private let choose: (ViewMode) -> Void

    /// A bar whose buttons call `choose` with the view picked.
    init(choose: @escaping (ViewMode) -> Void) {
        self.choose = choose
        viewButtons = NSSegmentedControl(
            images: [
                Self.image("list.bullet", String(localized: "as List")),
                Self.image("square.grid.2x2", String(localized: "as Icons")),
            ], trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: .zero)
        counts.font = .systemFont(ofSize: Self.fontSize)
        counts.textColor = .secondaryLabelColor
        counts.lineBreakMode = .byTruncatingTail
        counts.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        viewButtons.controlSize = .small
        viewButtons.target = self
        viewButtons.action = #selector(chose)
        viewButtons.toolTip = String(localized: "Show items as icons or as a list")
        viewButtons.setAccessibilityLabel(String(localized: "View"))
        viewButtons.setContentHuggingPriority(.required, for: .horizontal)
        setViews([counts], in: .leading)
        setViews([viewButtons], in: .trailing)
        edgeInsets = NSEdgeInsets(
            top: Self.barPadding, left: Self.sidePadding, bottom: Self.barPadding,
            right: Self.sidePadding)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Shows the counts and the view the folder is shown in.
    func show(counts text: String, mode: ViewMode) {
        if counts.stringValue != text { counts.stringValue = text }
        viewButtons.selectedSegment = Self.modes.firstIndex(of: mode) ?? 0
    }

    @objc private func chose() {
        guard Self.modes.indices.contains(viewButtons.selectedSegment) else { return }
        choose(Self.modes[viewButtons.selectedSegment])
    }

    private static func image(_ symbol: String, _ label: String) -> NSImage {
        NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage()
    }
}
