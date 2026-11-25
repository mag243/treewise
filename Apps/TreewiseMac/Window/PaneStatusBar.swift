import AppKit
import TreewiseCore
import TreewiseUI

/// The status bar as in Explorer (M5b): the counts at the left, the buttons
/// that show the folder as a list or as icons at the right. In a git repository the
/// branch comes before the counts (ADR 0149); it only informs, so a click does nothing.
@MainActor
final class PaneStatusBar: NSStackView {
    private static let barPadding: CGFloat = 4
    private static let sidePadding: CGFloat = 10
    private static let fontSize = NSFont.smallSystemFontSize
    private static let modes: [ViewMode] = [.list, .icons]
    private static let branchSpacing: CGFloat = 3
    private static let afterBranch: CGFloat = 12

    private let counts = NSTextField(labelWithString: "")
    private let branchSymbol = NSImageView()
    private let branch = NSTextField(labelWithString: "")
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
        setUpBranch()
        setViews([branchSymbol, branch, counts], in: .leading)
        setCustomSpacing(Self.branchSpacing, after: branchSymbol)
        setCustomSpacing(Self.afterBranch, after: branch)
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

    /// Shows the branch of the repository the folder is in; `nil` hides it.
    func show(branch status: GitRepositoryStatus?) {
        let locale = Locale.autoupdatingCurrent
        let text = status.flatMap { GitText.branch($0, locale: locale) }
        let help = status.flatMap { GitText.branchHelp($0, locale: locale) }
        if branch.stringValue != text ?? "" { branch.stringValue = text ?? "" }
        branch.toolTip = help
        branch.setAccessibilityLabel(help)
        branchSymbol.toolTip = help
        branch.isHidden = text == nil
        branchSymbol.isHidden = text == nil
    }

    private func setUpBranch() {
        branchSymbol.image = NSImage(
            systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)
        branchSymbol.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Self.fontSize, weight: .regular)
        branchSymbol.contentTintColor = .secondaryLabelColor
        branchSymbol.setAccessibilityElement(false)
        branch.font = .systemFont(ofSize: Self.fontSize)
        branch.textColor = .labelColor
        branch.lineBreakMode = .byTruncatingMiddle
        branch.setAccessibilityIdentifier("gitBranch")
        branch.setContentCompressionResistancePriority(.defaultLow + 1, for: .horizontal)
        for view in [branchSymbol, branch] as [NSView] { view.isHidden = true }
    }

    @objc private func chose() {
        guard Self.modes.indices.contains(viewButtons.selectedSegment) else { return }
        choose(Self.modes[viewButtons.selectedSegment])
    }

    private static func image(_ symbol: String, _ label: String) -> NSImage {
        NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage()
    }
}
