import AppKit
import TreewiseCore

/// The context menu of Settings' list of templates (ADR 0105): Rename, Duplicate, Export…
/// and Delete Template, for the template clicked.
extension TemplatesSettingsTab {
    func templateMenuItems() -> [NSMenuItem] {
        guard let template = selected else { return [] }
        let rename: () -> Void = { [weak self] in self?.beginRenaming() }
        let duplicate: () -> Void = { [weak self] in self?.duplicate(template) }
        let export: () -> Void = { [weak self] in self?.exportTemplate() }
        let delete: () -> Void = { [weak self] in self?.deleteTemplate() }
        return [
            ClosureMenuItem(String(localized: "Rename"), symbol: "pencil", handler: rename),
            ClosureMenuItem(
                String(localized: "Duplicate"), symbol: "plus.square.on.square", handler: duplicate),
            ClosureMenuItem(
                String(localized: "Export…"), symbol: "square.and.arrow.up", handler: export),
            .separator(),
            ClosureMenuItem(String(localized: "Delete Template"), symbol: "trash", handler: delete),
        ]
    }

    /// Starts typing a new name for the template selected, in its row.
    private func beginRenaming() {
        let row = table.selectedRow
        guard row >= 0, let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false),
            let name = Self.nameField(in: cell)
        else { return }
        view.window?.makeFirstResponder(name)
    }

    /// The editable name field somewhere inside a row's cell.
    static func nameField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap(nameField(in:)).first
    }

    private func duplicate(_ template: FolderTemplate) {
        let undo = view.window?.undoManager
        Task {
            guard let copy = await model.duplicate(template.id, undoManager: undo),
                let row = model.templates.firstIndex(where: { $0.id == copy })
            else { return }
            table.selectRowIndexes([row], byExtendingSelection: false)
        }
    }
}
