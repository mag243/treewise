import AppKit
import TreewiseCore
import TreewiseUI

/// The menu items of folder structure templates (ADR 0091, ADR 0094, ADR 0095, ADR 0099): New
/// Folders from Template ▸ with the saved templates, Save Folder Structure as Template…, and
/// Copy Folder Structure and Paste Folder Structure…, which make a folder's structure
/// elsewhere without saving a template. All are Treewise's own and show in every build.
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

    /// Copy Folder Structure, for `folder`: reads its folders, at every depth, for Paste
    /// Folder Structure….
    static func copyItem(for folder: FileItem, browser: BrowserState) -> NSMenuItem? {
        guard folder.kind == .folder else { return nil }
        return ClosureMenuItem(
            String(localized: "Copy Folder Structure"), symbol: "doc.on.doc"
        ) {
            let window = NSApp.keyWindow
            Task {
                do {
                    let tree = try await browser.fileSystem.folderTree(of: folder)
                    FolderTemplatesService.copiedStructure = tree
                } catch {
                    guard let window else { return }
                    let alert = NSAlert()
                    alert.messageText = String(localized: "The folder’s structure cannot be copied")
                    alert.informativeText =
                        (error as? FolderTree.Problem).map(TemplateProblemText.text(for:))
                        ?? String(localized: "The folder’s structure could not be read.")
                    alert.beginSheetModal(for: window) { _ in }
                }
            }
        }
    }

    /// Paste Folder Structure…, which opens the sheet that makes the structure copied in
    /// `folder`; greyed until a structure is copied.
    static func pasteItem(
        in folder: FileItem.ID, browser: BrowserState, undoManager: UndoManager?,
        enabled: Bool = true
    ) -> NSMenuItem {
        let copied = FolderTemplatesService.copiedStructure
        let item = ClosureMenuItem(
            String(localized: "Paste Folder Structure…"), symbol: "doc.on.clipboard"
        ) {
            guard let copied, let window = NSApp.keyWindow else { return }
            FolderTemplateSheet.present(
                .init(
                    title: String(localized: "Paste the Structure of “\(copied.name)”"),
                    tree: copied, templateID: nil, place: .inside(folder)),
                browser: browser, on: window, undoManager: undoManager)
        }
        item.isEnabled = enabled && copied != nil
        return item
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
