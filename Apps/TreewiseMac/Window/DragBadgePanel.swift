import AppKit
import TreewiseUI

/// The badge next to the pointer while dragging over a target, "Move to ‘X’"
/// or "Copy to ‘X’" (PLAN.md §4.1). A panel of its own, because a drop
/// target cannot change the image of a drag that may come from another app.
@MainActor
final class DragBadgePanel {
    static let shared = DragBadgePanel()

    /// Where the badge sits from the pointer, right and below as in the prototype.
    private static let offset = CGVector(dx: 16, dy: -18)

    private let panel: NSPanel
    private let host = DragBadgeView()

    private init() {
        panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.contentView = host
    }

    /// Shows the badge for a target near a point on screen.
    func show(_ badge: TreewiseUI.DragSession.Badge, at point: NSPoint) {
        host.show(badge.mode, text: badge.text(locale: .autoupdatingCurrent))
        place(at: point)
    }

    /// Shows why the drag cannot drop here, near a point on screen.
    func show(refusal: String, at point: NSPoint) {
        host.show(nil, text: refusal)
        place(at: point)
    }

    private func place(at point: NSPoint) {
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        panel.setFrame(
            NSRect(
                x: point.x + Self.offset.dx, y: point.y + Self.offset.dy - size.height,
                width: size.width, height: size.height),
            display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
