import AppKit
import TreewiseCore
import TreewiseUI

/// The menu items of folder structure templates (ADR 0091, ADR 0094, ADR 0095): New Folders
/// from Template ▸ with the saved templates, and Save Folder Structure as Template…. Both are
/// Treewise's own and show in every build (ADR 0099).
@MainActor
enum FolderTemplateMenu {
    /// New Folders from Template ▸, for making a template in `folder`.
    static func newFoldersItem(
        in folder: FileItem.ID, browser: BrowserState, undoManager: UndoManager?,
        enabled: Bool = true
    ) -> NSMenuItem? {
        let item = NSMenuItem(
            title: String(localized: "New Folders from Template"), action: nil, keyEquivalent: "")
        item.image = NSImage(
            systemSymbolName: "folder.badge.gearshape", accessibilityDescription: nil)
        item.isEnabled = enabled
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let templates = FolderTemplatesService.templates.templates
        for template in templates {
            submenu.addItem(
                ClosureMenuItem(template.name, symbol: "folder") {
                    open(template, in: folder, browser: browser, undoManager: undoManager)
                })
        }
        if templates.isEmpty {
            let none = NSMenuItem(
                title: String(localized: "No Templates"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            submenu.addItem(none)
        }
        item.submenu = submenu
        return item
    }

    /// Save Folder Structure as Template…, for `folder`.
    static func saveItem(for folder: FileItem, browser: BrowserState) -> NSMenuItem? {
        guard folder.kind == .folder else { return nil }
        return ClosureMenuItem(
            String(localized: "Save Folder Structure as Template…"), symbol: "square.and.arrow.down"
        ) {
            guard let window = NSApp.keyWindow else { return }
            SaveTemplateSheet.present(for: folder, browser: browser, on: window)
        }
    }

    /// Opens the sheet for `template` in `folder`: a template rooted at `{year}` fills a
    /// year's folder itself (ADR 0095); any other is made inside.
    private static func open(
        _ template: FolderTemplate, in folder: FileItem.ID, browser: BrowserState,
        undoManager: UndoManager?
    ) {
        guard let window = NSApp.keyWindow else { return }
        Task {
            let item = try? await browser.fileSystem.item(at: folder)
            let place: FolderTemplateSheetModel.Place
            if let item, template.yearOfFolderItFills(named: item.name) != nil {
                place = .filling(item)
            } else {
                place = .inside(folder)
            }
            FolderTemplateSheet.present(
                .init(
                    title: String(localized: "New Folders from “\(template.name)”"),
                    tree: template.root, templateID: template.id, place: place),
                browser: browser, on: window, undoManager: undoManager)
        }
    }
}
