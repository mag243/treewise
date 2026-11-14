import AppKit
import TreewiseCore
import TreewiseUI

/// Save Folder Structure as Template… (ADR 0091, ADR 0095, ADR 0099): reads the folder's
/// tree, lets the add-on, while it may work, write its years as `{year}`, and asks for a name in a sheet that shows what is
/// saved. A name another template has asks to replace it.
@MainActor
enum SaveTemplateSheet {
    /// Shows the sheet for `folder` on `window`.
    static func present(for folder: FileItem, browser: BrowserState, on window: NSWindow) {
        Task {
            guard let template = await read(folder, browser: browser, window: window) else {
                return
            }
            show(template, for: folder, on: window)
        }
    }

    private static func show(_ template: FolderTree, for folder: FileItem, on window: NSWindow) {
        let sheet = SaveTemplateSheetController(
            tree: template, proposedName: proposedName(for: folder))
        let sheetWindow = NSWindow(contentViewController: sheet)
        sheet.finish = { [weak window, weak sheetWindow] name in
            guard let window, let sheetWindow else { return }
            window.endSheet(sheetWindow)
            guard let name else { return }
            save(template, as: name, on: window)
        }
        window.beginSheet(sheetWindow)
    }

    /// The folder's tree as a template, or nil after saying why there is none. Saved as it
    /// is, its names as written; while the add-on may work, with the fields it recognizes,
    /// as a year written as `{year}` (ADR 0099).
    private static func read(_ folder: FileItem, browser: BrowserState, window: NSWindow) async
        -> FolderTree?
    {
        do {
            let tree = try await browser.fileSystem.folderTree(of: folder)
            guard let addOn = FolderTemplatesService.addOn(licences: browser.licences) else {
                try tree.checkTemplate()
                return tree
            }
            let template = try? await addOn.host.template(
                moduleID: addOn.moduleID, from: tree, yearAbove: YearFolders.year(of: folder.id),
                licence: addOn.licence())
            guard let template = template ?? nil else {
                try tree.checkTemplate()
                return tree
            }
            return template
        } catch let problem as FolderTree.Problem {
            tell(TemplateProblemText.text(for: problem), on: window)
            return nil
        } catch {}
        tell(String(localized: "The folder’s structure could not be read."), on: window)
        return nil
    }

    /// For a year's folder the name of the folder above it with “Year”, else its own name.
    private static func proposedName(for folder: FileItem) -> String {
        guard let year = YearFolders.year(of: folder.id), String(year) == folder.name,
            let above = folder.parentID?.rawValue.split(separator: "/").last
        else { return folder.name }
        return String(localized: "\(String(above)) Year")
    }

    private static func save(_ tree: FolderTree, as name: String, on window: NSWindow) {
        let templates = FolderTemplatesService.templates
        guard templates.template(named: name) != nil else {
            Task { await templates.save(tree, as: name) }
            return
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "A template named “\(name)” already exists.")
        alert.informativeText = String(localized: "Replace it with this folder’s structure?")
        alert.addButton(withTitle: String(localized: "Replace"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            Task { await templates.save(tree, as: name) }
        }
    }

    private static func tell(_ message: String, on window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = String(localized: "The folder cannot be saved as a template")
        alert.informativeText = message
        alert.beginSheetModal(for: window)
    }
}

/// The sheet: the name, the tree saved, and Cancel and Save.
@MainActor
private final class SaveTemplateSheetController: NSViewController, NSTextFieldDelegate {
    private static let width: CGFloat = 470
    private static let treeHeight: CGFloat = 220
    private static let padding: CGFloat = 20
    private static let spacing: CGFloat = 12

    private let tree: FolderTree
    private let name = NSTextField()
    private lazy var save = ClosureButton(title: String(localized: "Save")) { [weak self] in
        guard let self else { return }
        finish(name.stringValue.trimmingCharacters(in: .whitespaces))
    }
    /// Called with the name to save under, or nil on Cancel.
    var finish: (String?) -> Void = { _ in }

    init(tree: FolderTree, proposedName: String) {
        self.tree = tree
        super.init(nibName: nil, bundle: nil)
        name.stringValue = proposedName
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let title = NSTextField(
            labelWithString: String(localized: "Save Folder Structure as Template"))
        title.font = .preferredFont(forTextStyle: .headline)
        let explanation = NSTextField(
            labelWithString: String(
                localized: "The folders in it, at every depth. Files are not saved."))
        explanation.textColor = .secondaryLabelColor
        name.delegate = self
        name.setAccessibilityIdentifier("templateName")
        name.widthAnchor.constraint(equalToConstant: Self.width / 2).isActive = true
        let nameRow = NSStackView(views: [
            NSTextField(labelWithString: String(localized: "Name:")), name,
        ])
        let list = TemplateTreeList(height: Self.treeHeight)
        list.rows = TemplateTreeList.rows(of: tree)
        let count = TemplateTreeList.rows(of: tree).count
        let summary = NSTextField(
            wrappingLabelWithString: tree.hasYear
                ? String(
                    localized:
                        "\(count) folders. {year} stands for the year, so the template makes any year’s folders."
                )
                : String(localized: "\(count) folders."))
        summary.textColor = .secondaryLabelColor
        summary.preferredMaxLayoutWidth = Self.width - 2 * Self.padding
        let stack = NSStackView(views: [title, explanation, nameRow, list, summary, buttons()])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        list.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -2 * Self.padding)
            .isActive = true
        view = stack
        updateSave()
    }

    private func buttons() -> NSView {
        let cancel = ClosureButton(title: String(localized: "Cancel")) { [weak self] in
            self?.finish(nil)
        }
        cancel.keyEquivalent = "\u{1b}"
        save.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [spacer, cancel, save])
        row.widthAnchor.constraint(equalToConstant: Self.width - 2 * Self.padding).isActive = true
        return row
    }

    func controlTextDidChange(_ notification: Notification) {
        updateSave()
    }

    private func updateSave() {
        save.isEnabled = !name.stringValue.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
