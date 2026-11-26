import AppKit
import TreewiseUI

/// The folder side of a window: one half, or two side by side with a divider between them
/// while the window is split (ADR 0154). Each half is a `PaneController` for its pane; one
/// is added or removed as Split View is turned on or off.
@MainActor
final class SplitPanesController: NSViewController, NSSplitViewDelegate {
    /// The narrowest a half gets: its address caption and the list's name column whole.
    static let minimumHalfWidth: CGFloat = 320

    private let browser: BrowserState
    private let splitView = NSSplitView()
    private var halves: [PaneController] = []
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

    /// Shows a half for each pane the window has.
    private func update() {
        let wanted = browser.layout.panes.count
        while halves.count < wanted { addHalf() }
        while halves.count > wanted { removeHalf() }
        splitWidth.isActive = halves.count > 1
    }

    private func addHalf() {
        let half = PaneController(browser: browser, paneIndex: halves.count)
        addChild(half)
        halves.append(half)
        splitView.addArrangedSubview(half.view)
        guard halves.count > 1 else { return }
        // A new right half takes half of the width.
        splitView.layoutSubtreeIfNeeded()
        splitView.setPosition(splitView.bounds.width / 2, ofDividerAt: 0)
    }

    private func removeHalf() {
        let half = halves.removeLast()
        splitView.removeArrangedSubview(half.view)
        half.view.removeFromSuperview()
        half.removeFromParent()
    }

    // MARK: - NSSplitViewDelegate

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
