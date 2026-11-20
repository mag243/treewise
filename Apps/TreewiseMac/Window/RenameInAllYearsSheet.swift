import AppKit
import TreewiseCore
import TreewiseUI

/// Rename in All Years… (ADR 0139): on a folder inside a year's own folder, a sheet with the
/// new name, each year's folder with its old and new name and a checkbox, the years left out
/// with why, the templates corrected along, and Cancel and Rename.
@MainActor
enum RenameInAllYearsSheet {
    /// How long the status bar says how many folders were renamed.
    private static let messageDuration: Duration = .seconds(4)

    /// Rename in All Years…, for `item` when it is a folder inside a year's own folder.
    static func menuItem(
        for item: FileItem, browser: BrowserState, undoManager: UndoManager?, enabled: Bool
    ) -> NSMenuItem? {
        guard item.kind == .folder, ArchivePath(item.id) == nil,
            YearFolders.place(of: item.id) != nil
        else { return nil }
        let menuItem = ClosureMenuItem(
            String(localized: "Rename in All Years…"), symbol: "pencil.and.list.clipboard",
            enabled: enabled
        ) {
            guard let window = NSApp.keyWindow else { return }
            Task {
                await present(for: item, browser: browser, on: window, undoManager: undoManager)
            }
        }
        menuItem.setAccessibilityIdentifier("renameInAllYears")
        return menuItem
    }

    /// Opens the sheet for `item` on `window`, with `newName` typed in when there is one.
    static func present(
        for item: FileItem, newName: String? = nil, browser: BrowserState, on window: NSWindow,
        undoManager: UndoManager?
    ) async {
        let templates = FolderTemplatesService.templates
        await templates.load()
        guard
            let model = await RenameInAllYearsModel.make(
                for: item, in: browser.fileSystem, templates: templates.templates,
                madeFrom: {
                    await AppServices.folderSettings.settings(forFolderAt: $0.rawValue)?
                        .madeFrom ?? []
                })
        else { return }
        if let newName { model.newName = newName }
        let sheet = RenameInAllYearsSheetController(model: model)
        let sheetWindow = NSWindow(contentViewController: sheet)
        sheet.finish = { [weak window, weak sheetWindow] choice in
            guard let window, let sheetWindow else { return }
            window.endSheet(sheetWindow)
            Task {
                await finish(choice, model: model, browser: browser, on: window, undo: undoManager)
            }
        }
        window.beginSheet(sheetWindow) { _ in }
    }

    private static func finish(
        _ choice: RenameInAllYearsSheetController.Choice, model: RenameInAllYearsModel,
        browser: BrowserState, on window: NSWindow, undo undoManager: UndoManager?
    ) async {
        switch choice {
        case .cancel:
            return
        case .show(let folder):
            await browser.navigate(pane: browser.layout.focusedPaneIndex, to: folder)
        case .rename:
            let result = await browser.renameInAllYears(
                model, templates: FolderTemplatesService.templates,
                settings: AppServices.folderSettings, undoManager: undoManager)
            // The bar of each pane looks again: the names it compares changed (ADR 0139).
            NotificationCenter.default.post(name: FolderTemplateSheet.foldersMade, object: nil)
            switch result {
            case .nothing:
                return
            case .renamed(let count):
                tellRenamed(count, browser: browser)
            case .stopped(let failure, let count):
                if count > 0 { tellRenamed(count, browser: browser) }
                tell(failure, model: model, on: window)
            }
        }
    }

    private static func tellRenamed(_ count: Int, browser: BrowserState) {
        let message = String(localized: "Renamed \(count) folders.")
        browser.statusMessage = message
        Task {
            try? await Task.sleep(for: messageDuration)
            if browser.statusMessage == message { browser.statusMessage = nil }
        }
    }

    private static func tell(
        _ failure: BatchRenameOutcome.Failure, model: RenameInAllYearsModel, on window: NSWindow
    ) {
        let place = model.places.first { $0.folder == failure.item }
        let alert = NSAlert()
        alert.messageText =
            place.map {
                String(localized: "“\($0.name)” in \(model.label(of: $0)) could not be renamed")
            } ?? String(localized: "A folder could not be renamed")
        alert.informativeText = FailureMessage.text(for: failure.error, locale: .current)
        alert.beginSheetModal(for: window) { _ in }
    }
}

/// The sheet's view: the name, the years and the buttons, following the model.
@MainActor
private final class RenameInAllYearsSheetController: NSViewController, NSTextFieldDelegate {
    /// How the sheet ended.
    enum Choice {
        case cancel
        case rename
        /// Show in …: the folder that holds both names.
        case show(FileItem.ID)
    }

    private static let width: CGFloat = 520
    private static let listHeight: CGFloat = 200

    private let model: RenameInAllYearsModel
    private let name = NSTextField()
    private let rows = NSStackView()
    /// A checkbox for each template corrected along, on by default (ADR 0141).
    private lazy var templateBoxes: [NSButton] = model.templates.map { template in
        let box = NSButton(
            checkboxWithTitle: String(localized: "Also correct the template “\(template.name)”"),
            target: self, action: #selector(templateChanged))
        box.identifier = NSUserInterfaceItemIdentifier(template.id)
        box.state = .on
        return box
    }
    private lazy var rename = ClosureButton(title: "") { [weak self] in
        self?.finish(.rename)
    }
    /// Called with how the sheet ended.
    var finish: (Choice) -> Void = { _ in }

    init(model: RenameInAllYearsModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let title = NSTextField(
            labelWithString: String(localized: "Rename “\(model.oldName)” in All Years"))
        title.font = .preferredFont(forTextStyle: .headline)
        name.stringValue = model.newName
        name.delegate = self
        name.setAccessibilityIdentifier("renameInAllYearsName")
        name.widthAnchor.constraint(equalToConstant: Self.width / 2).isActive = true
        let nameRow = NSStackView(views: [
            NSTextField(labelWithString: String(localized: "New name:")), name,
        ])
        let cancel = ClosureButton(title: String(localized: "Cancel")) { [weak self] in
            self?.finish(.cancel)
        }
        rename.setAccessibilityIdentifier("renameInAllYearsRename")
        let buttons = SheetLayout.buttonRow(cancel: cancel, confirm: rename)
        let list = listView()
        let stack = SheetLayout.column([title, nameRow, list] + templateBoxes + [buttons])
        stack.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        for view in [list, buttons] {
            view.widthAnchor.constraint(
                equalTo: stack.widthAnchor, constant: -2 * SheetLayout.margin
            ).isActive = true
        }
        view = stack
        update()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // As Finder renames: the name selected, ready to type over.
        view.window?.makeFirstResponder(name)
        name.currentEditor()?.selectAll(nil)
    }

    private func listView() -> NSView {
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = SheetLayout.spacing / 2
        rows.edgeInsets = NSEdgeInsets(
            top: SheetLayout.spacing / 2, left: SheetLayout.spacing / 2,
            bottom: SheetLayout.spacing / 2, right: SheetLayout.spacing / 2)
        rows.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rows)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.documentView = document
        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: Self.listHeight),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor),
            rows.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
        return scroll
    }

    func controlTextDidChange(_ notification: Notification) {
        model.newName = name.stringValue
        update()
    }

    @objc private func templateChanged(_ box: NSButton) {
        guard let id = box.identifier?.rawValue else { return }
        if box.state == .on { model.uncorrected.remove(id) } else { model.uncorrected.insert(id) }
    }

    @objc private func checkChanged(_ box: NSButton) {
        guard let id = box.identifier.map({ FileItem.ID($0.rawValue) }) else { return }
        if box.state == .on { model.excluded.remove(id) } else { model.excluded.insert(id) }
        update()
    }

    private func update() {
        let unchanged = model.trimmedName == model.oldName
        rows.setViews(model.plan.entries.map { unchanged ? place($0.place) : row($0) }, in: .top)
        for row in rows.arrangedSubviews {
            row.widthAnchor.constraint(
                lessThanOrEqualTo: rows.widthAnchor, constant: -SheetLayout.spacing
            ).isActive = true
        }
        let count = model.renames.count
        rename.title =
            unchanged ? String(localized: "Rename") : String(localized: "Rename \(count) Folders")
        rename.isEnabled = model.canRename
    }

    /// A year's folder while the name is still the old one: where it is, nothing more.
    private func place(_ place: OneFolderName.Place) -> NSView {
        let field = NSTextField(labelWithString: "\(model.label(of: place))   \(place.name)")
        return truncating(field)
    }

    private func row(_ entry: OneFolderName.Entry) -> NSView {
        let label = model.label(of: entry.place)
        switch entry.outcome {
        case .renamed:
            let box = NSButton(
                checkboxWithTitle: "\(label)   \(entry.place.name)  →  \(model.trimmedName)",
                target: self, action: #selector(checkChanged))
            box.identifier = NSUserInterfaceItemIdentifier(entry.place.folder.rawValue)
            box.state = model.excluded.contains(entry.place.folder) ? .off : .on
            return truncating(box)
        case .alreadyNamed:
            return greyed(
                "\(label)   \(entry.place.name)   "
                    + String(localized: "already named so"))
        case .besideFolderNamed(let other):
            let text = greyed(
                "\(label)   \(entry.place.name)   "
                    + String(localized: "\(label) already has a folder “\(other)”"))
            let parent = entry.place.parent
            let title = String(localized: "Show in \(label)")
            let show = ClosureButton(title: title) { [weak self] in self?.finish(.show(parent)) }
            show.controlSize = .small
            show.setContentCompressionResistancePriority(.required, for: .horizontal)
            return NSStackView(views: [truncating(text), show])
        }
    }

    private func greyed(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.textColor = .secondaryLabelColor
        return truncating(field)
    }

    /// `control` cut short in the middle when its text is wider than the list, so a long
    /// name keeps its start and end and never widens the sheet.
    private func truncating<Control: NSControl>(_ control: Control) -> Control {
        control.lineBreakMode = .byTruncatingMiddle
        control.cell?.lineBreakMode = .byTruncatingMiddle
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.toolTip = (control as? NSButton)?.title ?? (control as? NSTextField)?.stringValue
        return control
    }
}
