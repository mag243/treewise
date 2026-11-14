import AppKit
import TreewiseCore
import TreewiseUI

/// The tree of the template chosen in Settings' Templates tab, edited in place (ADR 0095):
/// + adds a folder in the one selected, − deletes one with everything below it, a
/// double-click renames, dragging moves a folder into another, and Insert Field ▾ writes a
/// field in a name (ADR 0096). Every change goes to the model, which saves it with Undo.
@MainActor
final class TemplateTreeEditor: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate,
    NSTextFieldDelegate
{
    /// A folder of the tree, by its path below the root.
    final class Node {
        let path: [String]
        let tree: FolderTree
        let children: [Node]

        init(path: [String], tree: FolderTree) {
            self.path = path
            self.tree = tree
            children = tree.folders.map { Node(path: path + [$0.name], tree: $0) }
        }
    }

    private static let dragType = NSPasteboard.PasteboardType(
        "me.m-domain.treewise.template-folder")
    private static let pathSeparator = "\u{1F}"
    private static let height: CGFloat = 230
    private static let fields: [(field: String, title: String.LocalizationValue)] = [
        ("{year}", "Year"), ("{year:yy}", "Year in Two Digits"), ("{text}", "Text"),
        ("{seq}", "Number"), ("{date:yyyy-MM-dd}", "Date"),
    ]

    private let model: FolderTemplatesModel
    private let outline = NSOutlineView()
    private var root: Node?
    private var templateID: String?
    private var isLocked = false
    /// The folder to select once the tree shows it, and whether to start renaming it.
    private var pending: (path: [String], rename: Bool)?
    private lazy var add = NSButton(
        image: NSImage(named: NSImage.addTemplateName) ?? NSImage(), target: self,
        action: #selector(addFolder))
    private lazy var remove = NSButton(
        image: NSImage(named: NSImage.removeTemplateName) ?? NSImage(), target: self,
        action: #selector(removeFolder))
    private let insert = NSPopUpButton(frame: .zero, pullsDown: true)

    init(model: FolderTemplatesModel) {
        self.model = model
        super.init()
    }

    /// The editor's view: the tree and its buttons below it.
    func makeView() -> NSView {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.dataSource = self
        outline.delegate = self
        outline.doubleAction = #selector(renameSelected)
        outline.target = self
        outline.registerForDraggedTypes([Self.dragType])
        outline.setAccessibilityIdentifier("templateTreeEditor")
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: Self.height).isActive = true
        for button in [add, remove] { button.bezelStyle = .smallSquare }
        add.setAccessibilityLabel(String(localized: "Add Folder"))
        remove.setAccessibilityLabel(String(localized: "Delete Folder"))
        insert.addItem(withTitle: String(localized: "Insert Field"))
        for (field, title) in Self.fields {
            let item = NSMenuItem(
                title: String(localized: title), action: #selector(insertField(_:)),
                keyEquivalent: "")
            item.representedObject = field
            item.target = self
            insert.menu?.addItem(item)
        }
        insert.controlSize = .small
        insert.autoenablesItems = false
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [add, remove, spacer, insert])
        let stack = NSStackView(views: [scroll, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    /// Shows the template's tree, or none; a locked tree cannot be changed.
    func show(_ template: FolderTemplate?, locked: Bool) {
        let selected = selectedNode?.path
        templateID = template?.id
        isLocked = locked
        root = template.map { Node(path: [], tree: $0.root) }
        outline.reloadData()
        outline.expandItem(nil, expandChildren: true)
        if let selected { select(selected) }
        applyPending()
        updateButtons()
    }

    /// Selects the folder an edit made or moved, once the tree shows it, and starts renaming
    /// a folder just added.
    private func applyPending() {
        guard let pending, select(pending.path) else { return }
        self.pending = nil
        if pending.rename { renameSelected() }
    }

    private var selectedNode: Node? { outline.item(atRow: outline.selectedRow) as? Node }

    /// Selects the folder at `path`, and says whether the tree shows it.
    @discardableResult
    private func select(_ path: [String]) -> Bool {
        for row in 0..<outline.numberOfRows {
            guard (outline.item(atRow: row) as? Node)?.path == path else { continue }
            outline.selectRowIndexes([row], byExtendingSelection: false)
            outline.scrollRowToVisible(row)
            return true
        }
        return false
    }

    private func updateButtons() {
        let node = selectedNode
        add.isEnabled = !isLocked && node != nil
        remove.isEnabled = !isLocked && !(node?.path.isEmpty ?? true)
        insert.isEnabled = !isLocked && node != nil
        let belowRoot = !(node?.path.isEmpty ?? true)
        for item in insert.itemArray.dropFirst() {
            item.isEnabled = !(belowRoot && (item.representedObject as? String) == "{seq}")
        }
    }

    // MARK: Changes

    private var undoManager: UndoManager? { outline.window?.undoManager }

    @objc private func addFolder() {
        guard let id = templateID, let node = selectedNode else { return }
        let name = String(localized: "untitled folder")
        Task {
            guard
                let path = await model.addFolder(
                    in: node.path, of: id, named: name, undoManager: undoManager)
            else { return }
            pending = (path, true)
            applyPending()
        }
    }

    @objc private func removeFolder() {
        guard let id = templateID, let node = selectedNode, !node.path.isEmpty else { return }
        Task { await model.removeFolder(node.path, of: id, undoManager: undoManager) }
    }

    @objc private func renameSelected() {
        guard !isLocked, outline.selectedRow >= 0 else { return }
        outline.editColumn(0, row: outline.selectedRow, with: nil, select: true)
    }

    @objc private func insertField(_ item: NSMenuItem) {
        guard let id = templateID, let node = selectedNode,
            let field = item.representedObject as? String
        else { return }
        let name = node.tree.name.isEmpty ? field : node.tree.name + " " + field
        Task { await model.renameFolder(node.path, of: id, to: name, undoManager: undoManager) }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, let id = templateID else { return }
        let row = outline.row(for: field)
        guard let node = outline.item(atRow: row) as? Node, field.stringValue != node.tree.name
        else { return }
        let name = field.stringValue
        Task { await model.renameFolder(node.path, of: id, to: name, undoManager: undoManager) }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let node = item as? Node else { return root == nil ? 0 : 1 }
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let node = item as? Node else { return root as Any }
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? Node)?.children.isEmpty ?? true)
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any)
        -> (any NSPasteboardWriting)?
    {
        guard !isLocked, let node = item as? Node, !node.path.isEmpty else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(
            node.path.joined(separator: Self.pathSeparator), forType: Self.dragType)
        return pasteboardItem
    }

    func outlineView(
        _ outlineView: NSOutlineView, validateDrop info: any NSDraggingInfo,
        proposedItem item: Any?, proposedChildIndex index: Int
    ) -> NSDragOperation {
        guard item is Node else { return [] }
        outlineView.setDropItem(item, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return .move
    }

    func outlineView(
        _ outlineView: NSOutlineView, acceptDrop info: any NSDraggingInfo, item: Any?,
        childIndex index: Int
    ) -> Bool {
        guard let id = templateID, let target = item as? Node,
            let text = info.draggingPasteboard.string(forType: Self.dragType)
        else { return false }
        let path = text.components(separatedBy: Self.pathSeparator)
        Task {
            guard
                let moved = await model.moveFolder(
                    path, into: target.path, of: id, undoManager: undoManager)
            else { return }
            pending = (moved, false)
            applyPending()
        }
        return true
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any)
        -> NSView?
    {
        guard let node = item as? Node else { return nil }
        let cell = NSTableCellView()
        let icon = NSImageView(image: NSImage(named: NSImage.folderName) ?? NSImage())
        let name = NSTextField(string: node.tree.name)
        name.isBordered = false
        name.drawsBackground = false
        name.isEditable = !isLocked
        name.delegate = self
        name.lineBreakMode = .byTruncatingTail
        cell.textField = name
        cell.imageView = icon
        let stack = NSStackView(views: [icon, name])
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        updateButtons()
    }
}
