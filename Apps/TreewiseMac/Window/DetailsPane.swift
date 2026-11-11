import AppKit
import TreewiseCore
import TreewiseUI

/// Explorer's details pane at the right of the window (M5b): a preview of the
/// selected item and its name, kind, size, date and folder, or the count and
/// total size of several (`ItemDetails`).
@MainActor
final class DetailsPane: NSView {
    static let width: CGFloat = 260
    private static let previewHeight: CGFloat = 200
    private static let iconSize: CGFloat = 96
    private static let padding: CGFloat = 12
    private static let rowSpacing: CGFloat = 4
    private static let titleLines = 2

    private let browser: BrowserState
    private let preview = QuickLookView()
    private let icon = NSImageView()
    private let title = NSTextField(wrappingLabelWithString: "")
    private let rows = NSGridView()
    private var shownRows: [ItemDetails.Row] = []

    init(browser: BrowserState) {
        self.browser = browser
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(String(localized: "Details"))
        title.font = .preferredFont(forTextStyle: .headline)
        title.maximumNumberOfLines = Self.titleLines
        title.isSelectable = true
        title.preferredMaxLayoutWidth = Self.width - Self.padding * 2
        rows.rowSpacing = Self.rowSpacing
        let stack = NSStackView(views: [previewArea(), title, rows])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.padding
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            title.widthAnchor.constraint(equalToConstant: Self.width - Self.padding * 2),
        ])
        Observing.follow(self) { $0.update() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func previewArea() -> NSView {
        let area = NSView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        for view in [preview, icon] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            area.addSubview(view)
        }
        NSLayoutConstraint.activate([
            area.widthAnchor.constraint(equalToConstant: Self.width - Self.padding * 2),
            area.heightAnchor.constraint(equalToConstant: Self.previewHeight),
            preview.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: area.trailingAnchor),
            preview.topAnchor.constraint(equalTo: area.topAnchor),
            preview.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            icon.centerXAnchor.constraint(equalTo: area.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: area.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: Self.iconSize),
            icon.heightAnchor.constraint(equalToConstant: Self.iconSize),
        ])
        return area
    }

    private func update() {
        let selected = browser.selectedItems
        let details = ItemDetails(
            selected, calendar: .autoupdatingCurrent, locale: .autoupdatingCurrent,
            timeZone: .autoupdatingCurrent, now: .now)
        title.stringValue = details.title
        show(details.rows)
        showPreview(of: details.previewItem, selected: selected.first)
    }

    private func showPreview(of item: FileItem.ID?, selected: FileItem?) {
        // A file kept only online shows its icon: a preview could download it (ADR 0051).
        if let selected, selected.id.isInsideArchive {
            // Selecting an entry extracts nothing: its preview waits for Quick Look.
            showIcon(ItemIcon.image(for: selected))
        } else if let item, let selected, !selected.isContainer, !selected.isOnlyOnline {
            icon.isHidden = true
            preview.isHidden = false
            preview.show(item)
        } else {
            showIcon(FolderIcon.image(for: item ?? browser.layout.focusedPane.activeTab.folder))
        }
    }

    private func showIcon(_ image: NSImage) {
        preview.isHidden = true
        icon.isHidden = false
        icon.image = image
    }

    private func show(_ details: [ItemDetails.Row]) {
        guard details != shownRows else { return }
        shownRows = details
        while rows.numberOfRows > 0 { rows.removeRow(at: 0) }
        let font = NSFont.preferredFont(forTextStyle: .callout)
        let labels = details.map { row in
            let label = NSTextField(labelWithString: row.label)
            label.textColor = .secondaryLabelColor
            label.font = font
            return label
        }
        // A value wraps in what the widest label leaves of the pane.
        let valueWidth =
            Self.width - Self.padding * 2 - rows.columnSpacing
            - (labels.map(\.fittingSize.width).max() ?? 0)
        for (label, row) in zip(labels, details) {
            let value = NSTextField(wrappingLabelWithString: row.value)
            value.font = font
            value.isSelectable = true
            value.preferredMaxLayoutWidth = valueWidth
            rows.addRow(with: [label, value])
        }
        rows.rowAlignment = .firstBaseline
    }
}
