import AppKit
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// Settings' Templates tab (ADR 0091, ADR 0095, ADR 0099): the saved templates, renamed in the
/// list and deleted with −, Import… and Export…, and the tree of the one selected below,
/// edited in place. It is Treewise's own, so it works without the add-on.
@MainActor
final class TemplatesSettingsTab: NSViewController, NSTableViewDataSource, NSTableViewDelegate,
    NSTextFieldDelegate
{
    private static let padding: CGFloat = 20
    private static let spacing: CGFloat = 8
    private static let listHeight: CGFloat = 130
    private static let countWidth: CGFloat = 130

    private let model: FolderTemplatesModel
    private let editor: TemplateTreeEditor
    private let table = NSTableView()
    private let treeTitle = NSTextField(labelWithString: "")
    private let problem = NSTextField(wrappingLabelWithString: "")
    private lazy var remove = ActionButton(
        title: String(localized: "Delete Template"), symbol: "minus"
    ) { [weak self] in self?.deleteTemplate() }
    private static let importTitle = String(localized: "Import…")
    private static let exportTitle = String(localized: "Export…")
    private lazy var importButton = ClosureButton(title: Self.importTitle) { [weak self] in
        self?.importTemplate()
    }
    private lazy var exportButton = ClosureButton(title: Self.exportTitle) { [weak self] in
        self?.exportTemplate()
    }

    init(model: FolderTemplatesModel) {
        self.model = model
        editor = TemplateTreeEditor(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let hint = NSTextField(
            wrappingLabelWithString: String(
                localized:
                    "Save a folder’s structure with Save Folder Structure as Template… on the folder. Double-click a name to rename it."
            ))
        hint.textColor = .secondaryLabelColor
        treeTitle.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        problem.textColor = .systemOrange
        let stack = NSStackView(views: [
            hint, list(), footer(), treeTitle, editor.makeView(), problem,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        // As the other panes, the tab has the window's size, and its contents its width.
        let size = SettingsWindow.paneSize
        let pane = NSView(frame: NSRect(origin: .zero, size: size))
        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            pane.widthAnchor.constraint(equalToConstant: size.width),
            pane.heightAnchor.constraint(equalToConstant: size.height),
            stack.topAnchor.constraint(equalTo: pane.topAnchor, constant: Self.padding),
            stack.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: Self.padding),
            stack.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -Self.padding),
        ])
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        view = pane
        Observing.follow(self) { $0.update() }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        Task { await model.load() }
    }

    private func list() -> NSView {
        let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        let count = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("count"))
        count.width = Self.countWidth
        table.addTableColumn(name)
        table.addTableColumn(count)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(renameSelected)
        table.setAccessibilityIdentifier("templatesList")
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: Self.listHeight).isActive = true
        return scroll
    }

    private func footer() -> NSView {
        let row = NSStackView()
        row.setViews([remove], in: .leading)
        row.setViews([importButton, exportButton], in: .trailing)
        return row
    }

    private var selected: FolderTemplate? {
        model.templates.indices.contains(table.selectedRow)
            ? model.templates[table.selectedRow] : nil
    }

    private func update() {
        let chosen = selected?.id
        table.reloadData()
        if let chosen, let row = model.templates.firstIndex(where: { $0.id == chosen }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        } else if !model.templates.isEmpty, table.selectedRow < 0 {
            table.selectRowIndexes([0], byExtendingSelection: false)
        }
        showSelected()
        problem.stringValue = model.problem.map(TemplateProblemText.text(for:)) ?? ""
        remove.isEnabled = selected != nil
        exportButton.isEnabled = selected != nil
    }

    private func showSelected() {
        let template = selected
        treeTitle.stringValue =
            template.map { String(localized: "Folders of “\($0.name)”") }
            ?? String(localized: "No Templates")
        editor.show(template)
    }

    // MARK: Actions

    private func deleteTemplate() {
        guard let template = selected else { return }
        let undo = view.window?.undoManager
        Task { await model.delete(template.id, undoManager: undo) }
    }

    @objc private func renameSelected() {
        guard table.clickedRow >= 0 else { return }
        table.editColumn(0, row: table.clickedRow, with: nil, select: true)
    }

    private func importTemplate() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            Task {
                let data = (try? Data(contentsOf: url)) ?? Data()
                await self.model.importTemplate(from: data)
            }
        }
    }

    private func exportTemplate() {
        guard let window = view.window, let template = selected else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = template.name + "." + FolderTemplateFile.pathExtension
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url,
                let data = try? FolderTemplateFile.data(of: template)
            else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: NSTableViewDataSource and Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { model.templates.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let template = model.templates[row]
        guard tableColumn?.identifier.rawValue == "name" else {
            let count = TemplateTreeList.rows(of: template.root).count
            let text =
                template.hasYear
                ? String(localized: "\(count) folders · {year}")
                : String(localized: "\(count) folders")
            let label = NSTextField(labelWithString: text)
            label.textColor = .secondaryLabelColor
            return label
        }
        let name = NSTextField(string: template.name)
        name.isBordered = false
        name.drawsBackground = false
        name.isEditable = true
        name.delegate = self
        return name
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        showSelected()
        remove.isEnabled = selected != nil
        exportButton.isEnabled = selected != nil
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        let row = table.row(for: field)
        guard model.templates.indices.contains(row) else { return }
        let template = model.templates[row]
        guard field.stringValue != template.name else { return }
        let name = field.stringValue
        let undo = view.window?.undoManager
        Task { await model.rename(template.id, to: name, undoManager: undo) }
    }
}
