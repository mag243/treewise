import AppKit
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// Settings' Templates tab (ADR 0091, ADR 0095, ADR 0099), laid out as the Names tab: the
/// saved templates under their heading, each with its number of folders, renamed in the list
/// and deleted with −, Import… and Export…, and the tree of the one selected below, edited in
/// place. It is Treewise's own, so it works without the add-on; while the add-on may work, a
/// row below says whether a year's folder offers the folders of the year before it lacks
/// (ADR 0102).
@MainActor
final class TemplatesSettingsTab: NSViewController, NSTableViewDataSource, NSTableViewDelegate,
    NSTextFieldDelegate
{
    private static let spacing: CGFloat = 8
    private static let groupSpacing: CGFloat = 20
    private static let listHeight: CGFloat = 100
    private static let countSpacing: CGFloat = 6

    private var contextMenu: SettingsListMenu?
    let model: FolderTemplatesModel
    private let editor: TemplateTreeEditor
    let table = NSTableView()
    private let treeTitle = SettingsList.subheading("")
    private let problem = NSTextField(wrappingLabelWithString: "")
    private let offersMissing = NSButton(
        checkboxWithTitle: String(localized: "Offer from the year before"),
        target: nil, action: nil)
    private let missingForm = SettingsForm()
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
        let hint = SettingsList.note(
            String(
                localized:
                    "Save a folder’s structure with Save Folder Structure as Template… on the folder. Double-click a name to rename it."
            ))
        problem.textColor = Tint.problem
        problem.preferredMaxLayoutWidth = SettingsList.width
        let section = [
            SettingsList.heading(String(localized: "Folder Templates")), list(), footer(), hint,
        ]
        let tree = [treeTitle, editor.makeView(), problem]
        let stack = NSStackView(views: section + tree + [missingFolders()])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.setCustomSpacing(Self.groupSpacing, after: hint)
        stack.setCustomSpacing(Self.groupSpacing, after: problem)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in section + tree {
            view.widthAnchor.constraint(equalToConstant: SettingsList.width).isActive = true
        }
        view = SettingsList.pane(stack)
        Observing.follow(self) { $0.update() }
    }

    /// Missing folders: Offer from the year before, with its note, as the Names tab's rows
    /// (ADR 0102).
    private func missingFolders() -> NSView {
        offersMissing.target = self
        offersMissing.action = #selector(offersMissingChanged)
        offersMissing.setAccessibilityIdentifier("offersMissingFolders")
        missingForm.row("Missing folders:", offersMissing)
        missingForm.note(
            "A year’s folder offers, in a bar, the folders of the year before it lacks. Add Missing Folders… on the folder offers them too.",
            width: SettingsForm.noteWidth)
        return missingForm.grid
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        missingForm.grid.isHidden = !FolderTemplatesService.addOnMayWork
        offersMissing.state = AppServices.settings.offersMissingFolders ? .on : .off
        Task { await model.load() }
    }

    @objc private func offersMissingChanged() {
        AppServices.settings.offersMissingFolders = offersMissing.state == .on
    }

    private func list() -> NSView {
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(renameSelected)
        table.setAccessibilityIdentifier("templatesList")
        contextMenu = SettingsListMenu(for: table) { [weak self] _ in
            self?.templateMenuItems() ?? []
        }
        return SettingsList.scroll(table, height: Self.listHeight)
    }

    private func footer() -> NSView {
        let row = NSStackView()
        row.setViews([remove], in: .leading)
        row.setViews([importButton, exportButton], in: .trailing)
        return row
    }

    var selected: FolderTemplate? {
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
        problem.isHidden = model.problem == nil
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

    func deleteTemplate() {
        guard let template = selected else { return }
        let undo = view.window?.undoManager
        Task { await model.delete(template.id, undoManager: undo) }
    }

    @objc private func renameSelected() {
        guard table.clickedRow >= 0,
            let cell = table.view(atColumn: 0, row: table.clickedRow, makeIfNecessary: false),
            let name = Self.nameField(in: cell)
        else { return }
        view.window?.makeFirstResponder(name)
    }

    private func importTemplate() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            Task {
                // Read off the main actor; a file that cannot be read is no template, as
                // the import says.
                let data = await Task.detached { (try? Data(contentsOf: url)) ?? Data() }.value
                await self.model.importTemplate(from: data)
            }
        }
    }

    func exportTemplate() {
        guard let window = view.window, let template = selected else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        // A name that says what the file is, and its extension that says it is JSON
        // (ADR 0104).
        panel.nameFieldStringValue =
            String(localized: "\(template.name) Folder Template") + "."
            + FolderTemplateFile.pathExtension
        panel.isExtensionHidden = false
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try FolderTemplateFile.data(of: template).write(to: url, options: .atomic)
            } catch {
                // A file that cannot be written says why, as a failed import does.
                let alert = NSAlert()
                alert.messageText = String(localized: "The template could not be exported")
                alert.informativeText = error.localizedDescription
                alert.beginSheetModal(for: window) { _ in }
            }
        }
    }

    // MARK: NSTableViewDataSource and Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { model.templates.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let template = model.templates[row]
        let name = NSTextField(string: template.name)
        name.isBordered = false
        name.drawsBackground = false
        name.isEditable = true
        name.delegate = self
        // An editable field has no width of its own: it takes its name's.
        name.sizeToFit()
        name.widthAnchor.constraint(greaterThanOrEqualToConstant: name.frame.width)
            .isActive = true
        let folders = TemplateTreeList.rows(of: template.root).count
        let count = NSTextField(
            labelWithString: template.hasYear
                ? String(localized: "\(folders) folders · {year}")
                : String(localized: "\(folders) folders"))
        count.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        count.textColor = .secondaryLabelColor
        let line = NSStackView(views: [name, count])
        line.alignment = .firstBaseline
        line.spacing = Self.countSpacing
        // In the middle of its row, as the names of Name Patterns are.
        let cell = NSView()
        cell.addSubview(line)
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            line.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor),
            line.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
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
