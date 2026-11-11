import AppKit
import TreewiseCore
import TreewiseUI

/// The list of files in the overview of proposed names, an outline: the rows that ask
/// something of the user, then a group of the names that already fit, closed at first, as
/// they ask nothing. Selecting a row edits its name; the list follows the selection.
@MainActor
final class NameReviewList: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let model: NameReviewModel
    private let outline = NameReviewOutline()
    let nameField = NameReviewField()
    /// The group of names that already fit.
    private let fittingGroup = FittingGroup()
    /// The outline's items for the files, one object for each, as an outline knows its
    /// items by identity.
    private var items: [FileItem.ID: RowItem] = [:]
    private var shownIDs: [FileItem.ID] = []
    private var shownHidden: [FileItem.ID] = []
    private var shownSelection: FileItem.ID?
    private var isApplyingState = false

    init(model: NameReviewModel) {
        self.model = model
        super.init()
    }

    /// The outline in a scroll view.
    func makeView() -> NSView {
        let column = NSTableColumn(identifier: .init("file"))
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.usesAutomaticRowHeights = true
        outline.style = .inset
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.doubleAction = #selector(editClickedRow)
        outline.keys = { [weak self] event in self?.handle(event) ?? false }
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        Observing.follow(self) { $0.update() }
        return scroll
    }

    private func update() {
        let ids = model.rows.map(\.id)
        let hidden = model.hiddenRows.map(\.id)
        _ = model.session
        _ = model.conflicts
        _ = model.readingCount
        isApplyingState = true
        defer { isApplyingState = false }
        if ids != shownIDs || hidden != shownHidden {
            shownIDs = ids
            shownHidden = hidden
            outline.reloadData()
        } else {
            showRows()
        }
        fittingGroup.title = hiddenLine
        selectModelRow()
    }

    /// Shows every row on screen as the review has it now, without making them again, so
    /// the name being typed keeps its editor.
    private func showRows() {
        let visible = outline.rows(in: outline.visibleRect)
        guard visible.length > 0 else { return }
        for row in visible.location..<NSMaxRange(visible) {
            (outline.view(atColumn: 0, row: row, makeIfNecessary: false) as? NameReviewRowView)?
                .show(isSelected: (outline.item(atRow: row) as? RowItem)?.id == model.selectedID)
            (outline.view(atColumn: 0, row: row, makeIfNecessary: false) as? FittingGroupView)?
                .show(fittingGroup.title)
        }
        outline.noteHeightOfRows(
            withIndexesChanged: IndexSet(integersIn: visible.location..<NSMaxRange(visible)))
    }

    private func selectModelRow() {
        let selected = model.selectedID
        defer { shownSelection = selected }
        guard let selected else { return outline.deselectAll(nil) }
        if shownHidden.contains(selected) { outline.expandItem(fittingGroup) }
        let row = outline.row(forItem: item(for: selected))
        guard row >= 0 else { return }
        if outline.selectedRow != row {
            outline.selectRowIndexes([row], byExtendingSelection: false)
        }
        if shownSelection != selected {
            outline.scrollRowToVisible(row)
            // A Quick Look panel that is shown follows the selection, as in the list.
            QuickLookSource.shared.follow([selected.diskURL].compactMap { $0 })
        }
    }

    private var hiddenLine: String {
        let skipped = model.hiddenRows.filter { model.isAlwaysSkipped($0.id) }.count
        let fitting = model.hiddenRows.count - skipped
        return skipped == 0
            ? String(localized: "\(fitting) files already fit")
            : String(localized: "\(fitting) files already fit, \(skipped) always skipped")
    }

    // MARK: - Editing and keys

    @objc private func editClickedRow() {
        let row = outline.clickedRow
        guard let id = (outline.item(atRow: row) as? RowItem)?.id else { return }
        model.selectedID = id
        edit(id)
    }

    /// Gives the name of `id` the keyboard focus, once its row shows the field.
    private func edit(_ id: FileItem.ID) {
        Task { @MainActor [nameField] in nameField.startEditing() }
    }

    /// The overview's keys while the list has the focus: Return edits the name and Space
    /// shows the file, as in the file list; ← and → step through the options, A approves
    /// and S skips.
    private func handle(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask),
            let id = model.selectedID
        else { return false }
        switch event.keyCode {
        case KeyCode.returnKey:
            guard let entry = model.session?.entry(id), !entry.isOutOfScope, !entry.restsFitting
            else { return false }
            edit(id)
            return true
        case KeyCode.space:
            QuickLookSource.shared.toggle([id.diskURL].compactMap { $0 })
            return true
        case KeyCode.leftArrow: return model.handle(.previous, isTyping: false)
        case KeyCode.rightArrow: return model.handle(.next, isTyping: false)
        default: break
        }
        switch event.charactersIgnoringModifiers {
        case "a": return model.handle(.approve, isTyping: false)
        case "s": return model.handle(.skip, isTyping: false)
        default: return false
        }
    }

    // MARK: - NSOutlineViewDataSource and NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return shownIDs.count + (shownHidden.isEmpty ? 0 : 1) }
        return item is FittingGroup ? shownHidden.count : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item is FittingGroup { return self.item(for: shownHidden[index]) }
        return index < shownIDs.count ? self.item(for: shownIDs[index]) : fittingGroup
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is FittingGroup
    }

    func outlineView(
        _ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any
    ) -> NSView? {
        if item is FittingGroup {
            let view = FittingGroupView { [weak self] in self?.toggleFittingGroup() }
            view.show(fittingGroup.title)
            return view
        }
        guard let id = (item as? RowItem)?.id else { return nil }
        let view = NameReviewRowView(id: id, model: model, nameField: nameField)
        view.show(isSelected: id == model.selectedID)
        return view
    }

    private func toggleFittingGroup() {
        if outline.isItemExpanded(fittingGroup) {
            outline.collapseItem(fittingGroup)
        } else {
            outline.expandItem(fittingGroup)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        !(item is FittingGroup)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingState,
            let id = (outline.item(atRow: outline.selectedRow) as? RowItem)?.id
        else { return }
        model.selectedID = id
    }

    private func item(for id: FileItem.ID) -> RowItem {
        if let item = items[id] { return item }
        let item = RowItem(id: id)
        items[id] = item
        return item
    }
}

/// The item of a file in the outline.
@MainActor
private final class RowItem: NSObject {
    let id: FileItem.ID

    init(id: FileItem.ID) {
        self.id = id
    }
}

/// The item of the group of names that already fit.
@MainActor
private final class FittingGroup: NSObject {
    var title = ""
}

/// The row of the group of names that already fit: a button that opens and closes it.
@MainActor
private final class FittingGroupView: NSTableCellView {
    private let label: ClosureButton

    init(toggle: @escaping @MainActor () -> Void) {
        label = ClosureButton(title: "", run: toggle)
        super.init(frame: .zero)
        label.isBordered = false
        label.font = .preferredFont(forTextStyle: .caption1)
        label.contentTintColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show(_ title: String) {
        label.title = title
    }
}

/// The outline of the overview, which hands its keys to the overview before its own.
@MainActor
private final class NameReviewOutline: NSOutlineView {
    var keys: (NSEvent) -> Bool = { _ in false }

    override func keyDown(with event: NSEvent) {
        if !keys(event) { super.keyDown(with: event) }
    }
}

/// The keys the overview answers, by their virtual key codes.
private enum KeyCode {
    static let returnKey: UInt16 = 36
    static let space: UInt16 = 49
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
}
