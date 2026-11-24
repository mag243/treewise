import AppKit
import TreewiseCore
import TreewiseUI

/// Explorer's details pane at the right of the window (M5b): a preview of the
/// selected item and its name, kind, size, date and folder, or the count and
/// total size of several (`ItemDetails`), and for a folder made from templates, which
/// ones, each with Forget (ADR 0141).
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
    /// The templates the one folder selected was made from, once read.
    private var madeFrom: (folder: FileItem.ID, templates: [FolderTemplate])?

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
        NotificationCenter.default.addObserver(
            self, selector: #selector(foldersMade), name: FolderTemplateSheet.foldersMade,
            object: nil)
    }

    /// Folders made from a template may be the one selected, read before it was made from it.
    @objc private func foldersMade() {
        madeFrom = nil
        update()
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
        let folder = selected.count == 1 && selected[0].kind == .folder ? selected[0].id : nil
        if madeFrom?.folder != folder { madeFrom = nil }
        show(details.rows)
        if let folder, madeFrom == nil { readTemplates(of: folder) }
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

    private func readTemplates(of folder: FileItem.ID) {
        let bar = FolderTemplatesService.bar(for: browser)
        Task {
            let templates = await bar.templates(madeFrom: folder)
            let selected = browser.selectedItems
            guard selected.count == 1, selected[0].id == folder else { return }
            madeFrom = (folder, templates)
            show(shownRows, again: true)
        }
    }

    private func show(_ details: [ItemDetails.Row], again: Bool = false) {
        guard again || details != shownRows else { return }
        shownRows = details
        removeRows()
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
        addTemplateRows(font: font, width: valueWidth)
        rows.rowAlignment = .firstBaseline
    }

    /// Removes every row and its views: `removeRow(at:)` leaves a row's views in the grid.
    private func removeRows() {
        while rows.numberOfRows > 0 {
            let row = rows.row(at: 0)
            for index in 0..<row.numberOfCells {
                row.cell(at: index).contentView?.removeFromSuperview()
            }
            rows.removeRow(at: 0)
        }
    }

    /// Made from, with each template's name and Forget.
    private func addTemplateRows(font: NSFont, width: CGFloat) {
        guard let madeFrom else { return }
        for (index, template) in madeFrom.templates.enumerated() {
            let label = NSTextField(
                labelWithString: index == 0 ? String(localized: "Made from") : "")
            label.textColor = .secondaryLabelColor
            label.font = font
            let name = NSTextField(labelWithString: template.name)
            name.font = font
            name.lineBreakMode = .byTruncatingMiddle
            name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let forget = NSButton(
                image: NSImage(
                    systemSymbolName: "xmark.circle.fill",
                    accessibilityDescription: String(localized: "Forget “\(template.name)”"))
                    ?? NSImage(),
                target: self, action: #selector(forget(_:)))
            forget.isBordered = false
            forget.contentTintColor = .tertiaryLabelColor
            forget.identifier = NSUserInterfaceItemIdentifier(template.id)
            forget.toolTip = String(localized: "Forget that this folder was made from it")
            let value = NSStackView(views: [name, forget])
            // As wide as a value may be, so a long name is cut short, not the pane widened.
            value.widthAnchor.constraint(lessThanOrEqualToConstant: width).isActive = true
            rows.addRow(with: [label, value])
        }
    }

    /// Forget: this folder was not made from the template; Undo remembers it again.
    @objc private func forget(_ button: NSButton) {
        guard let id = button.identifier?.rawValue, let folder = madeFrom?.folder else { return }
        change(folder, template: id, forgetting: true)
    }

    /// Forgets or remembers the template `id` of `folder`, and registers the other for Undo.
    private func change(_ folder: FileItem.ID, template id: String, forgetting: Bool) {
        let bar = FolderTemplatesService.bar(for: browser)
        let undoManager = SharedUndo.manager
        undoManager.registerUndo(withTarget: self) { pane in
            pane.change(folder, template: id, forgetting: !forgetting)
        }
        undoManager.setActionName(String(localized: "Forget Template"))
        Task {
            if forgetting {
                await bar.forget(id, madeFrom: folder)
            } else {
                await bar.remember(made: folder, from: id, yearBefore: nil)
            }
            madeFrom = nil
            update()
        }
    }
}
