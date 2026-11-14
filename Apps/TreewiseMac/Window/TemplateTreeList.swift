import AppKit
import TreewiseCore

/// A template's tree in a sheet (ADR 0091, ADR 0095): each folder indented below the one it
/// is in, a folder already there in grey, and one a file stops struck through with why.
@MainActor
final class TemplateTreeList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    /// A folder as the list shows it.
    struct Row: Hashable {
        let name: String
        let depth: Int
        let state: FolderTemplatePlan.State?
    }

    private static let indent: CGFloat = 18
    private static let rowHeight: CGFloat = 20
    private static let iconSize: CGFloat = 16
    private static let cellID = NSUserInterfaceItemIdentifier("TemplateTreeCell")
    private let table = NSTableView()

    /// The folders shown, in order.
    var rows: [Row] = [] {
        didSet { table.reloadData() }
    }

    init(height: CGFloat) {
        super.init(frame: .zero)
        let column = NSTableColumn(identifier: Self.cellID)
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = Self.rowHeight
        table.style = .plain
        table.selectionHighlightStyle = .none
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityIdentifier("templateTree")
        documentView = table
        hasVerticalScroller = true
        borderType = .bezelBorder
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The rows of a plan's entries.
    static func rows(of entries: [FolderTemplatePlan.Entry]) -> [Row] {
        entries.map { Row(name: $0.path.last ?? "", depth: $0.path.count - 1, state: $0.state) }
    }

    /// The rows of a tree, without states.
    static func rows(of tree: FolderTree, depth: Int = 0) -> [Row] {
        [Row(name: tree.name, depth: depth, state: nil)]
            + tree.folders.flatMap { rows(of: $0, depth: depth + 1) }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let shown = rows[row]
        let icon = NSImageView(image: NSImage(named: NSImage.folderName) ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        let label = NSTextField(labelWithAttributedString: Self.title(of: shown))
        label.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [icon, label])
        stack.spacing = 6
        stack.edgeInsets.left = CGFloat(shown.depth) * Self.indent + 4
        if shown.state == .existing { icon.alphaValue = 0.45 }
        return stack
    }

    private static func title(of row: Row) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [:]
        var text = row.name
        switch row.state {
        case .existing:
            attributes[.foregroundColor] = NSColor.tertiaryLabelColor
            text += "  " + String(localized: "already there")
        case .leftOut:
            attributes[.foregroundColor] = NSColor.systemOrange
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            let reason = String(localized: "a file has this name · left out")
            let shown = NSMutableAttributedString(string: row.name, attributes: attributes)
            shown.append(
                NSAttributedString(
                    string: "  " + reason, attributes: [.foregroundColor: NSColor.systemOrange]))
            return shown
        case .new, nil:
            break
        }
        return NSAttributedString(string: text, attributes: attributes)
    }
}
