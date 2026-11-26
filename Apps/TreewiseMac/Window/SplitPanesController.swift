import AppKit
import TreewiseUI

/// The folder side of a window: one half, or two side by side with a divider between them
/// while the window is split (ADR 0154). Each half is a `PaneController` for its pane; one
/// is added or removed as Split View is turned on or off.
@MainActor
final class SplitPanesController: NSViewController, NSSplitViewDelegate {
    /// The narrowest a half gets: its address caption and the list's name column whole.
    static let minimumHalfWidth: CGFloat = 320
    /// How far the divider moves before it is kept again, so a window's resizing, which
    /// keeps the halves' shares, saves nothing new.
    private static let positionTolerance = 0.005

    private let browser: BrowserState
    private let splitView = NSSplitView()
    private var halves: [PaneController] = []
    /// Whether a new right half waits for the window's width to take its share of it.
    private var dividerWaits = false
    /// Keeps a split window wide enough for two halves; active only while split.
    private lazy var splitWidth = splitView.widthAnchor.constraint(
        greaterThanOrEqualToConstant: 2 * Self.minimumHalfWidth + splitView.dividerThickness)

    init(browser: BrowserState) {
        self.browser = browser
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.setAccessibilityIdentifier("splitPanes")
        view = splitView
        Observing.follow(self) { $0.update() }
    }

    /// Shows a half for each pane the window has; when one comes or goes, the keyboard
    /// focus goes to the active half, as the menus and the command bar act on it.
    private func update() {
        let wanted = browser.layout.panes.count
        let before = halves.count
        while halves.count < wanted { addHalf() }
        while halves.count > wanted { removeHalf() }
        splitWidth.isActive = halves.count > 1
        guard before > 0, before != halves.count else { return }
        let active = browser.layout.focusedPaneIndex
        if halves.indices.contains(active) { halves[active].takeFocus() }
    }

    private func addHalf() {
        let half = PaneController(browser: browser, paneIndex: halves.count)
        addChild(half)
        halves.append(half)
        splitView.addArrangedSubview(half.view)
        guard halves.count > 1 else { return }
        // The divider goes where the window had it, once the window has a width: a
        // restored window adds its right half before it is laid out.
        dividerWaits = true
        view.needsLayout = true
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard dividerWaits, halves.count > 1, splitView.bounds.width > 0 else { return }
        dividerWaits = false
        splitView.setPosition(
            splitView.bounds.width * browser.dividerPosition, ofDividerAt: 0)
    }

    private func removeHalf() {
        let half = halves.removeLast()
        splitView.removeArrangedSubview(half.view)
        half.view.removeFromSuperview()
        half.removeFromParent()
    }

    // MARK: - NSSplitViewDelegate

    /// Keeps where the divider is, for the window's next split and its restoring.
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !dividerWaits, halves.count > 1, splitView.bounds.width > 0,
            let left = splitView.arrangedSubviews.first
        else { return }
        let position = left.frame.width / splitView.bounds.width
        if abs(position - browser.dividerPosition) > Self.positionTolerance {
            browser.dividerPosition = position
        }
    }

    func splitView(
        _ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        max(proposedMinimumPosition, Self.minimumHalfWidth)
    }

    func splitView(
        _ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        min(proposedMaximumPosition, splitView.bounds.width - Self.minimumHalfWidth)
    }
}
