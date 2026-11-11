import AppKit
import TreewiseCore

/// The path of the address bar: one button per folder with a separator
/// between them, and the empty part after it, which turns the bar into a
/// field. The first path that fits at full names is shown: the folders at the
/// start go behind `«` one by one (ADR 0069); when even the folder alone does
/// not fit, its name is cut short in the middle.
@MainActor
final class AddressPath: NSView {
    private static let spacing: CGFloat = 2
    private static let padding: CGFloat = 6
    private static let menuIconSize = NSSize(width: 16, height: 16)

    private let row = NSStackView()
    private let overflow = NSPopUpButton(frame: .zero, pullsDown: true)
    private let overflowSeparator: AddressSeparator
    private let typeArea: TypePathArea
    private var crumbs: [PathComponent] = []
    private var buttons: [CrumbButton] = []
    private var separators: [AddressSeparator] = []
    private var hiddenCount = 0
    private let go: (FileItem.ID) -> Void

    /// A path whose folders call `go`, and whose empty part calls `edit`.
    init(go: @escaping (FileItem.ID) -> Void, edit: @escaping () -> Void) {
        self.go = go
        overflowSeparator = AddressSeparator(label: "", open: go)
        typeArea = TypePathArea(edit: edit)
        super.init(frame: .zero)
        configureOverflow()
        row.orientation = .horizontal
        row.spacing = Self.spacing
        row.distribution = .fill
        row.alignment = .height
        row.edgeInsets = NSEdgeInsets(top: 0, left: Self.padding, bottom: 0, right: Self.padding)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func configureOverflow() {
        overflow.isBordered = false
        (overflow.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        let title = String(localized: "Folders Above")
        overflow.toolTip = title
        overflow.setAccessibilityLabel(title)
        overflow.setContentHuggingPriority(.required, for: .horizontal)
    }

    /// Shows `crumbs`, whose drops go through `drop`, with the subfolders
    /// behind each separator.
    func show(_ crumbs: [PathComponent], drop: @escaping DropAction) {
        guard crumbs != self.crumbs else { return }
        self.crumbs = crumbs
        buttons = crumbs.enumerated().map { index, crumb in
            CrumbButton(crumb, isLast: index == crumbs.count - 1, drop: drop, go: go)
        }
        // As in Explorer, the folder shown ends the path: its own subfolders are in the list.
        separators = crumbs.dropLast().map { crumb in
            AddressSeparator(label: String(localized: "Folders in \(crumb.name)"), open: go)
        }
        var views: [NSView] = [overflow, overflowSeparator]
        for (index, button) in buttons.enumerated() {
            views.append(button)
            if separators.indices.contains(index) { views.append(separators[index]) }
        }
        views.append(typeArea)
        row.setViews(views, in: .leading)
        hiddenCount = -1
        needsLayout = true
    }

    /// Gives each separator the folders inside the folder before it.
    func show(subfolders: [String: [FileItem]]) {
        for (crumb, separator) in zip(crumbs, separators) {
            separator.folders = subfolders[crumb.path] ?? []
        }
        hiddenCount = -1
        needsLayout = true
    }

    override func layout() {
        let fitting = firstHiddenCountThatFits(in: bounds.width)
        if fitting != hiddenCount {
            hide(first: fitting)
        }
        super.layout()
    }

    /// The fewest folders to put behind `«` for the path to fit `width`, or
    /// all but the last when none fits.
    private func firstHiddenCountThatFits(in width: CGFloat) -> Int {
        guard !buttons.isEmpty else { return 0 }
        let crumbWidths = buttons.map(\.fittingSize.width)
        let separatorWidths = separators.map(\.fittingSize.width)
        let overflowWidth = overflow.fittingSize.width + overflowSeparator.fittingSize.width
        let available = width - Self.padding * 2
        for count in 0..<buttons.count {
            let shown =
                crumbWidths[count...].reduce(0, +) + separatorWidths.dropFirst(count).reduce(0, +)
            let views = (buttons.count - count) * 2 - 1 + (count > 0 ? 2 : 0)
            let total =
                shown + (count > 0 ? overflowWidth : 0)
                + Self.spacing * CGFloat(views)
            if total <= available { return count }
        }
        return buttons.count - 1
    }

    /// Puts the first `count` folders behind `«`, the nearest last in its menu.
    private func hide(first count: Int) {
        hiddenCount = count
        overflow.isHidden = count == 0
        overflowSeparator.isHidden = count == 0
        for (index, button) in buttons.enumerated() { button.isHidden = index < count }
        for (index, separator) in separators.enumerated() { separator.isHidden = index < count }
        guard count > 0 else { return }
        overflowSeparator.folders = separators[count - 1].folders
        overflowSeparator.setAccessibilityLabel(
            String(localized: "Folders in \(crumbs[count - 1].name)"))
        overflow.menu = overflowMenu(crumbs[..<count])
    }

    private func overflowMenu(_ hidden: ArraySlice<PathComponent>) -> NSMenu {
        let menu = NSMenu()
        // A pull-down button shows its first item as its own title.
        let title = NSMenuItem()
        title.image = NSImage(
            systemSymbolName: "chevron.left.2",
            accessibilityDescription: String(localized: "Folders Above"))
        menu.addItem(title)
        for crumb in hidden {
            let item = NSMenuItem(
                title: crumb.name, action: #selector(chose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = crumb.path
            let icon = FolderIcon.image(for: FileItem.ID(crumb.path)).copy() as? NSImage
            icon?.size = Self.menuIconSize
            item.image = icon
            menu.addItem(item)
        }
        return menu
    }

    @objc private func chose(_ item: NSMenuItem) {
        guard let path = item.representedObject as? String else { return }
        go(FileItem.ID(path))
    }
}

/// The empty part of the address bar after the path: a click turns the bar
/// into a field to type a path in.
@MainActor
private final class TypePathArea: NSView {
    private let edit: () -> Void

    init(edit: @escaping () -> Void) {
        self.edit = edit
        super.init(frame: .zero)
        setContentHuggingPriority(.init(1), for: .horizontal)
        setContentCompressionResistancePriority(.init(1), for: .horizontal)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(String(localized: "Type a path"))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        edit()
    }

    override func isAccessibilityEnabled() -> Bool {
        true
    }

    override func accessibilityPerformPress() -> Bool {
        edit()
        return true
    }
}
