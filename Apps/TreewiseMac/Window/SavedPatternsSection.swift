import AppKit
import TreewiseCore
import TreewiseUI

/// The saved patterns in Settings (ADR 0068), as Mail lists its rules: a list of their
/// names, the default marked, put in order by dragging; + and − below it, Make Default,
/// and the selected one's name and pattern in labelled fields beneath, the pattern in the
/// colours of its fields and with the problem of its form. The last pattern stays.
@MainActor
final class SavedPatternsSection: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private static let listHeight: CGFloat = 150
    private static let width: CGFloat = 440
    private static let spacing: CGFloat = 8
    private static let checkSpacing: CGFloat = 6
    private static let dragType = NSPasteboard.PasteboardType("me.m-domain.treewise.pattern")

    private let settings: BrowserSettings
    private let table = NSTableView()
    private let editor: SavedPatternEditor
    private lazy var remove = ActionButton(
        title: String(localized: "Remove Pattern"), symbol: "minus"
    ) { [weak self] in self?.removeSelected() }
    private lazy var makeDefault = SettingsForm.button("Make Default") { [weak self] in
        guard let self, let selected else { return }
        settings.savedPatterns.makeDefault(selected.id)
    }
    private var shown: [SavedPattern] = []
    private var shownDefault: SavedPattern.ID?
    private var selection: SavedPattern.ID?

    init(settings: BrowserSettings) {
        self.settings = settings
        editor = SavedPatternEditor(settings: settings)
        super.init()
    }

    private var patterns: SavedPatterns { settings.savedPatterns }
    private var selected: SavedPattern? {
        patterns.patterns.first { $0.id == selection } ?? patterns.patterns.first
    }

    /// The section's views, one under the other.
    func makeView() -> NSView {
        let header = NSTextField(labelWithString: String(localized: "Name Patterns"))
        header.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let note = NSTextField(
            wrappingLabelWithString: String(
                localized:
                    "The default is offered to a folder without a pattern of its own. A folder keeps the version of a pattern it uses, and is offered a newer one."
            ))
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = Self.width
        let stack = NSStackView(views: [header, list(), buttons(), editor.makeView(), note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        Observing.follow(self) { $0.update() }
        return stack
    }

    private func list() -> NSView {
        let column = NSTableColumn(identifier: .init("pattern"))
        table.addTableColumn(column)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.style = .fullWidth
        table.registerForDraggedTypes([Self.dragType])
        table.setAccessibilityLabel(String(localized: "Name Patterns"))
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: Self.width),
            scroll.heightAnchor.constraint(equalToConstant: Self.listHeight),
        ])
        return scroll
    }

    private func buttons() -> NSView {
        let addPattern: @MainActor () -> Void = { [weak self] in self?.addPattern() }
        let add = ActionButton(
            title: String(localized: "Add Pattern"), symbol: "plus", run: addPattern)
        remove.toolTip = String(localized: "Remove")
        let row = NSStackView()
        row.setViews([add, remove], in: .leading)
        row.setViews([makeDefault], in: .trailing)
        row.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        return row
    }

    private func update() {
        let patterns = settings.savedPatterns
        if patterns.patterns != shown || patterns.defaultPattern.id != shownDefault {
            shown = patterns.patterns
            shownDefault = patterns.defaultPattern.id
            table.reloadData()
        }
        let selected = selected
        if let row = shown.firstIndex(where: { $0.id == selected?.id }),
            table.selectedRow != row
        {
            table.selectRowIndexes([row], byExtendingSelection: false)
        }
        remove.isEnabled = shown.count > 1
        makeDefault.isEnabled = selected?.id != patterns.defaultPattern.id
        editor.edit(selected)
    }

    /// Keeps the pattern being typed, as the user leaves the list.
    func commitEditing() {
        editor.commit()
    }

    private func addPattern() {
        if case .success(let id) = settings.savedPatterns.save(
            name: String(localized: "New Pattern"), text: "{date:yyyy.MM.dd} {text}")
        {
            choose(id)
        }
    }

    private func removeSelected() {
        guard let selected else { return }
        settings.savedPatterns.remove(selected.id)
        choose(settings.savedPatterns.patterns.first?.id)
    }

    private func choose(_ id: SavedPattern.ID?) {
        editor.commit()
        selection = id
        update()
    }

    // MARK: - NSTableViewDataSource and NSTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        shown.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let pattern = shown[row]
        let isDefault = pattern.id == shownDefault
        let check = NSImageView(
            image: NSImage(
                systemSymbolName: "checkmark",
                accessibilityDescription: String(localized: "Default"))
                ?? NSImage())
        check.contentTintColor = .controlAccentColor
        check.alphaValue = isDefault ? 1 : 0
        check.setAccessibilityElement(isDefault)
        let name = NSTextField(labelWithString: pattern.name)
        let cell = NSStackView(views: [check, name])
        cell.spacing = Self.checkSpacing
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        guard shown.indices.contains(row), shown[row].id != selection else { return }
        choose(shown[row].id)
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int)
        -> (any NSPasteboardWriting)?
    {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.dragType)
        return item
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard info.draggingSource as? NSTableView === table else { return [] }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(
        _ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard
            let text = info.draggingPasteboard.pasteboardItems?.first?.string(
                forType: Self.dragType),
            let from = Int(text)
        else { return false }
        settings.savedPatterns.move(fromOffsets: [from], toOffset: row)
        return true
    }
}

/// The name and the pattern of the selected saved pattern. A pattern is kept when the user
/// commits it, with Return, by leaving the field or by leaving the pattern, not with each
/// key, as each change of the text is a version that folders are offered (ADR 0068).
@MainActor
private final class SavedPatternEditor: NSObject, NSTextFieldDelegate {
    private static let fieldWidth: CGFloat = 360

    private let settings: BrowserSettings
    private let name = NSTextField(string: "")
    private let pattern = PatternFieldDriver(text: "")
    private let problem = NSTextField(labelWithString: "")
    private var editing: SavedPattern.ID?
    private var text = ""

    init(settings: BrowserSettings) {
        self.settings = settings
        super.init()
        name.placeholderString = String(localized: "Name")
        name.setAccessibilityLabel(String(localized: "Name"))
        name.delegate = self
        pattern.field.setAccessibilityLabel(String(localized: "Pattern"))
        pattern.onChange = { [weak self] in self?.typed($0) }
        pattern.onSubmit = { [weak self] in self?.commit() }
        pattern.onEndEditing = { [weak self] in self?.commit() }
        problem.font = .preferredFont(forTextStyle: .caption1)
        problem.textColor = .systemRed
    }

    func makeView() -> NSView {
        let form = SettingsForm()
        form.row("Name:", name)
        form.row("Pattern:", pattern.field)
        form.row(nil, problem)
        for field in [name, pattern.field] {
            field.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        }
        form.grid.column(at: 0).xPlacement = .trailing
        return form.grid
    }

    /// Shows `saved`, keeping the one shown before when its pattern can be read.
    func edit(_ saved: SavedPattern?) {
        guard saved?.id != editing else { return }
        commit()
        editing = saved?.id
        name.stringValue = saved?.name ?? ""
        text = saved?.text ?? ""
        pattern.show(text)
        showProblem()
    }

    /// Keeps the typed pattern when it can be read; the same text makes no new version.
    func commit() {
        guard let editing, NameTemplate.problemInForm(of: text) == nil else { return }
        settings.savedPatterns.change(editing, to: text)
    }

    private func typed(_ text: String) {
        self.text = text
        showProblem()
    }

    private func showProblem() {
        let found = NameTemplate.problemInForm(of: text)
        problem.stringValue = found.map(NameReviewText.text(for:)) ?? ""
        problem.isHidden = found == nil
    }

    /// An empty name is not taken: the last one given stays.
    func controlTextDidChange(_ notification: Notification) {
        guard let editing else { return }
        settings.savedPatterns.rename(editing, to: name.stringValue)
    }
}
