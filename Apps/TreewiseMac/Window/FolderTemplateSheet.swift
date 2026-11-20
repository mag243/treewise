import AppKit
import TreewiseCore
import TreewiseUI

/// New Folders from Template's sheet (ADR 0091, ADR 0095 to ADR 0097): the template's fields,
/// the tree they make with what is there in grey, the checkbox that offers the template in
/// the folder's new folders, and Cancel and Create Folders.
@MainActor
enum FolderTemplateSheet {
    /// Posted once Create Folders made folders, so the template bar of each pane looks again
    /// at what its folder lacks (ADR 0102).
    static let foldersMade = Notification.Name("TreewiseFolderTemplateFoldersMade")

    /// How long the status bar says how many folders were made.
    private static let messageDuration: Duration = .seconds(4)

    /// What the sheet makes.
    struct Making {
        /// The sheet's title.
        let title: String
        /// The template's tree.
        let tree: FolderTree
        /// The saved template's id, which the checkbox offers; nil for the year before.
        let templateID: String?
        /// Where the tree goes.
        let place: FolderTemplateSheetModel.Place
        /// The year's folder the tree was read from, whose templates the folder made takes
        /// on (ADR 0141); nil for a saved template or a copied structure.
        var yearBefore: FileItem.ID?
    }

    /// Shows the sheet on `window`, for `browser`'s folders.
    static func present(
        _ making: Making, browser: BrowserState, on window: NSWindow, undoManager: UndoManager?
    ) {
        let model = FolderTemplateSheetModel(
            template: making.tree, place: making.place, fileSystem: browser.fileSystem,
            currentYear: Calendar.current.component(.year, from: .now),
            today: today())
        let sheet = FolderTemplateSheetController(model: model, making: making)
        let sheetWindow = NSWindow(contentViewController: sheet)
        // The sheet holds this closure, so it reaches the sheet only weakly.
        sheet.finish = { [weak window, weak sheetWindow, weak sheet] create in
            guard let window, let sheetWindow else { return }
            // Read before the sheet ends, which may let it go.
            let offers = sheet?.offers == true
            window.endSheet(sheetWindow)
            guard create, let tree = model.tree, let folder = model.folderMadeIn else { return }
            let made = Made(
                tree: tree, folder: folder, offering: offers ? making.templateID : nil,
                origin: making.templateID, yearBefore: making.yearBefore)
            Task { await make(made, browser: browser, window: window, undoManager: undoManager) }
        }
        window.beginSheet(sheetWindow)
        Task {
            await model.start()
            sheet.update()
        }
    }

    /// What Create Folders makes, and the template it offers in the folder's new folders.
    private struct Made {
        let tree: FolderTree
        let folder: FileItem.ID
        let offering: String?
        /// The saved template the folders come from, and the year's folder they were read
        /// from, which the root made remembers (ADR 0141).
        let origin: String?
        let yearBefore: FileItem.ID?
    }

    private static func make(
        _ made: Made, browser: BrowserState, window: NSWindow, undoManager: UndoManager?
    ) async {
        guard
            let outcome = await browser.createFolders(
                making: made.tree, in: made.folder, undoManager: undoManager)
        else { return }
        await FolderTemplatesService.giveNames(of: made.tree, to: outcome.made)
        if made.origin != nil || made.yearBefore != nil {
            let root = FileItem.ID(made.folder.rawValue + "/" + made.tree.name)
            await FolderTemplatesService.bar(for: browser).remember(
                made: root, from: made.origin, yearBefore: made.yearBefore)
        }
        NotificationCenter.default.post(name: foldersMade, object: nil)
        if let templateID = made.offering {
            await FolderTemplatesService.bar(for: browser).offer(
                templateID, in: made.folder)
        }
        let message = String(localized: "Made \(outcome.madeCount) folders.")
        browser.statusMessage = message
        Task {
            try? await Task.sleep(for: messageDuration)
            if browser.statusMessage == message { browser.statusMessage = nil }
        }
        guard !outcome.leftOut.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Some folders were left out")
        let names = outcome.leftOut.map { "“\($0.joined(separator: "/"))”" }
        alert.informativeText = String(
            localized: "A file has the name of \(names.formatted(.list(type: .and))).")
        alert.beginSheetModal(for: window) { _ in }
    }

    private static func today() -> FolderTemplateValues.Day {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return FolderTemplateValues.Day(
            year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}

/// The sheet's view: its fields, the tree and the buttons, following the model.
@MainActor
private final class FolderTemplateSheetController: NSViewController, NSTextFieldDelegate {
    private static let width: CGFloat = 470
    private static let treeHeight: CGFloat = 220
    private static let fieldWidth: CGFloat = 64
    private static let years = 1900...2099
    private static let mostNumber = 999_999

    private let model: FolderTemplateSheetModel
    private let making: FolderTemplateSheet.Making
    /// Called with whether to create the folders.
    var finish: (Bool) -> Void = { _ in }

    private let tree = TemplateTreeList(height: treeHeight)
    private let summary = NSTextField(wrappingLabelWithString: "")
    private let year = NSTextField()
    private let yearStepper = NSStepper()
    private let number = NSTextField()
    private let numberStepper = NSStepper()
    private let text = NSTextField()
    private let date = NSDatePicker()
    private let offer = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private static let createTitle = String(localized: "Create Folders")
    private lazy var create = ClosureButton(title: Self.createTitle) { [weak self] in
        self?.finish(true)
    }

    /// Whether the checkbox offers the template for the folder's new folders.
    var offers: Bool { offer.state == .on && !offer.isHidden }

    init(model: FolderTemplateSheetModel, making: FolderTemplateSheet.Making) {
        self.model = model
        self.making = making
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let title = NSTextField(labelWithString: making.title)
        title.font = .preferredFont(forTextStyle: .headline)
        var views: [NSView] = [title]
        views += model.fields.map(row(for:))
        views += [tree, summary, offerRow(), buttons()]
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = SheetLayout.spacing
        stack.edgeInsets = SheetLayout.insets
        stack.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        tree.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -2 * SheetLayout.margin)
            .isActive = true
        summary.preferredMaxLayoutWidth = Self.width - 2 * SheetLayout.margin
        view = stack
        update()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if model.fields.contains(.text) { view.window?.makeFirstResponder(text) }
    }

    private func row(for field: FolderTemplateField) -> NSView {
        switch field {
        case .year:
            return labelled("Year:", stepping(year, yearStepper, range: Self.years))
        case .number:
            return labelled("Number:", stepping(number, numberStepper, range: 0...Self.mostNumber))
        case .text:
            text.delegate = self
            text.placeholderString = String(localized: "Required")
            text.setAccessibilityIdentifier("templateText")
            text.widthAnchor.constraint(equalToConstant: Self.width / 2).isActive = true
            return labelled("Text:", text)
        case .date:
            date.datePickerElements = .yearMonthDay
            date.datePickerStyle = .textFieldAndStepper
            date.dateValue = .now
            date.target = self
            date.action = #selector(dateChanged)
            return labelled("Date:", date)
        }
    }

    private func stepping(_ field: NSTextField, _ stepper: NSStepper, range: ClosedRange<Int>)
        -> NSView
    {
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(stepped(_:))
        return NSStackView(views: [field, stepper])
    }

    private func labelled(_ label: String.LocalizationValue, _ control: NSView) -> NSView {
        let name = NSTextField(labelWithString: String(localized: label))
        return NSStackView(views: [name, control])
    }

    private func offerRow() -> NSView {
        // Offering a template in a folder is the add-on's (ADR 0099).
        if making.templateID != nil, FolderTemplatesService.addOnMayWork,
            case .inside(let folder) = making.place
        {
            let name = folder.rawValue.split(separator: "/").last.map(String.init) ?? ""
            offer.title = String(localized: "Offer for new folders in \(name)")
        } else {
            offer.isHidden = true
        }
        return offer
    }

    private func buttons() -> NSView {
        let cancel = ClosureButton(title: String(localized: "Cancel")) { [weak self] in
            self?.finish(false)
        }
        let row = SheetLayout.buttonRow(cancel: cancel, confirm: create)
        row.widthAnchor.constraint(equalToConstant: Self.width - 2 * SheetLayout.margin).isActive =
            true
        return row
    }

    /// Shows the model's values, tree and problem.
    func update() {
        if let value = model.values.year {
            year.stringValue = String(value)
            yearStepper.integerValue = value
        }
        if let value = model.values.number {
            number.stringValue = String(value.value)
            numberStepper.integerValue = value.value
        }
        tree.rows = TemplateTreeList.rows(of: model.entries)
        create.isEnabled = model.canCreate
        if let problem = model.problem {
            summary.stringValue = TemplateProblemText.text(for: problem)
            summary.textColor = Tint.problem
        } else if model.toMakeCount == 0 {
            summary.stringValue = String(localized: "Every folder is already there.")
            summary.textColor = .secondaryLabelColor
        } else {
            summary.stringValue = String(localized: "Makes \(model.toMakeCount) folders.")
            summary.textColor = .secondaryLabelColor
        }
    }

    private func change(_ apply: @escaping @MainActor (FolderTemplateSheetModel) async -> Void) {
        Task {
            await apply(model)
            update()
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        let typed = field.stringValue
        if field === text {
            change { await $0.setText(typed) }
        } else if let value = Int(typed), field === year, Self.years.contains(value) {
            change { await $0.setYear(value) }
        } else if let value = Int(typed), field === number, value >= 0 {
            change { await $0.setNumber(value) }
        }
    }

    @objc private func stepped(_ stepper: NSStepper) {
        let value = stepper.integerValue
        if stepper === yearStepper {
            change { await $0.setYear(value) }
        } else {
            change { await $0.setNumber(value) }
        }
    }

    @objc private func dateChanged() {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date.dateValue)
        let day = FolderTemplateValues.Day(
            year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
        change { await $0.setDate(day) }
    }
}
