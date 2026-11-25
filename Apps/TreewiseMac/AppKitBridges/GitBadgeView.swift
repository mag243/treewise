import AppKit
import TreewiseCore
import TreewiseUI

/// The mark at the bottom left of an item's icon that says its git state (ADR 0149): a full
/// dot for modified, a ring for new, a diamond for a conflict, each in its colour, so it
/// does not rest on colour alone. A ring of the list's background sets it off from any
/// icon. An unchanged or ignored item shows none; an ignored one is dimmed instead.
final class GitBadgeView: NSView {
    /// The width of the background's ring, as a share of the badge's side.
    private static let ringShare: CGFloat = 0.14
    /// The width of the new state's ring, as a share of the badge's side.
    private static let strokeShare: CGFloat = 0.2

    /// The state shown; `nil` or ignored hides the badge.
    var state: GitItemState? {
        didSet {
            guard state != oldValue else { return }
            isHidden = !Self.shows(state)
            setAccessibilityLabel(
                state.map { GitText.state($0, locale: .autoupdatingCurrent) })
            needsDisplay = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Whether a state shows as a badge.
    static func shows(_ state: GitItemState?) -> Bool {
        state != nil && state != .ignored
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let state, Self.shows(state) else { return }
        let side = min(bounds.width, bounds.height)
        let square = NSRect(
            x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(ovalIn: square).fill()
        let inner = square.insetBy(dx: side * Self.ringShare, dy: side * Self.ringShare)
        Self.colour(of: state).set()
        switch state {
        case .modified:
            NSBezierPath(ovalIn: inner).fill()
        case .new:
            let width = side * Self.strokeShare
            let ring = NSBezierPath(ovalIn: inner.insetBy(dx: width / 2, dy: width / 2))
            ring.lineWidth = width
            ring.stroke()
        case .conflict:
            let diamond = NSBezierPath()
            diamond.move(to: NSPoint(x: inner.midX, y: inner.minY))
            diamond.line(to: NSPoint(x: inner.maxX, y: inner.midY))
            diamond.line(to: NSPoint(x: inner.midX, y: inner.maxY))
            diamond.line(to: NSPoint(x: inner.minX, y: inner.midY))
            diamond.close()
            diamond.fill()
        case .ignored:
            return
        }
    }

    private static func colour(of state: GitItemState) -> NSColor {
        switch state {
        case .modified: .systemOrange
        case .new: .systemGreen
        case .conflict: .systemRed
        case .ignored: .secondaryLabelColor
        }
    }
}

/// How an item's icon shows its git state: a badge at its bottom left, and dimmed when
/// git ignores it.
enum GitIconLook {
    /// How much an ignored item's icon shows.
    static let ignoredAlpha: CGFloat = 0.45
    /// How far the badge reaches past the icon's corner.
    static let overhang: CGFloat = 2

    /// The icon's opacity for a state.
    static func alpha(for state: GitItemState?) -> CGFloat {
        state == .ignored ? ignoredAlpha : 1
    }

    /// Puts `badge` at the bottom left of `icon`, `side` points wide, in `container`.
    @MainActor
    static func place(_ badge: GitBadgeView, on icon: NSView, side: CGFloat, in container: NSView) {
        badge.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badge, positioned: .above, relativeTo: icon)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: icon.leadingAnchor, constant: -overhang),
            badge.bottomAnchor.constraint(equalTo: icon.bottomAnchor, constant: overhang),
            badge.widthAnchor.constraint(equalToConstant: side),
            badge.heightAnchor.constraint(equalToConstant: side),
        ])
    }
}
