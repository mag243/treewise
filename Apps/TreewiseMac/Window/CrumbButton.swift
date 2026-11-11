import AppKit
import TreewiseCore

/// A folder of the address bar's path: a button with its icon and name that
/// goes there, and a drop target into that folder (ADR 0003) with the same
/// badge and rules as the list and the sidebar, outlined while a drag may
/// drop on it.
@MainActor
final class CrumbButton: NSButton {
    private static let iconSize: CGFloat = 13
    private static let fontSize: CGFloat = 11
    private static let outlineRadius: CGFloat = 4
    private static let outlineWidth: CGFloat = 2
    /// Just below the priority with which a window keeps the size it is dragged to.
    static let yieldsToWindow = NSLayoutConstraint.Priority(
        NSLayoutConstraint.Priority.dragThatCannotResizeWindow.rawValue - 1)

    let folder: FileItem.ID
    private let drop: DropAction
    private let go: (FileItem.ID) -> Void
    private var isTargeted = false {
        didSet { needsDisplay = true }
    }

    /// A button for `crumb`, the last of the path when `isLast`; This Mac
    /// starts every path on a volume, so before the end it shows only its
    /// icon, which says enough (ADR 0069).
    init(
        _ crumb: PathComponent, isLast: Bool, drop: @escaping DropAction,
        go: @escaping (FileItem.ID) -> Void
    ) {
        folder = FileItem.ID(crumb.path)
        self.drop = drop
        self.go = go
        super.init(frame: .zero)
        let iconOnly = !isLast && folder == .computer
        let icon = FolderIcon.image(for: folder).copy() as? NSImage
        icon?.size = NSSize(width: Self.iconSize, height: Self.iconSize)
        image = icon
        title = crumb.name
        imagePosition = iconOnly ? .imageOnly : .imageLeading
        toolTip = iconOnly ? crumb.name : nil
        font =
            isLast
            ? .systemFont(ofSize: Self.fontSize, weight: .semibold)
            : .systemFont(ofSize: Self.fontSize)
        isBordered = false
        lineBreakMode = .byTruncatingMiddle
        setAccessibilityLabel(crumb.name)
        // The path gives way to the window's width, which hides its first
        // folders; the folder shown gives way first when nothing else fits.
        setContentCompressionResistancePriority(
            isLast ? .defaultLow : Self.yieldsToWindow, for: .horizontal)
        target = self
        action = #selector(goThere)
        registerForDraggedTypes(DropRouting.pasteboardTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func goThere() {
        go(folder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isTargeted else { return }
        let inset = Self.outlineWidth / 2
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: Self.outlineRadius,
            yRadius: Self.outlineRadius)
        outline.lineWidth = Self.outlineWidth
        NSColor.controlAccentColor.setStroke()
        outline.stroke()
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        operation(of: sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        operation(of: sender)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        isTargeted = false
        DropRouting.finish()
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        isTargeted = false
        return DropRouting.perform(
            sender.draggingPasteboard, on: DropRouting.item(at: folder), with: drop)
    }

    private func operation(of info: any NSDraggingInfo) -> NSDragOperation {
        let operation = DropRouting.operation(of: info, over: DropRouting.item(at: folder))
        isTargeted = !operation.isEmpty
        return operation
    }
}
