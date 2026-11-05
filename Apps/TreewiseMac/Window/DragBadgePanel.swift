import AppKit
import SwiftUI
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
    private let host = NSHostingView(rootView: DragBadgeView(badge: nil))

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
        if host.rootView.badge != badge { host.rootView = DragBadgeView(badge: badge) }
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

/// The badge itself: a dot with an arrow for move or a plus for copy, and the text.
struct DragBadgeView: View {
    private static let dotSize: CGFloat = 18
    private static let shadowRadius: CGFloat = 9
    /// Room around the capsule for its shadow inside the panel.
    private static let margin: CGFloat = 12

    let badge: TreewiseUI.DragSession.Badge?

    var body: some View {
        if let badge {
            HStack(spacing: 6) {
                Image(systemName: badge.mode == .move ? "arrow.right" : "plus")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .background(badge.mode == .move ? Color.accentColor : Color.green, in: Circle())
                Text(badge.text(locale: .autoupdatingCurrent))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, 5)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator))
            .shadow(color: .black.opacity(0.16), radius: Self.shadowRadius, y: 6)
            .padding(Self.margin)
        }
    }
}
