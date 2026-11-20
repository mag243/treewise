import Foundation
import Observation
import TreewiseCore
import TreewiseUI

/// The templates each folder shown was made from (ADR 0141), read when a folder's contents
/// show, so a folder's menu offers Made from ▸ at once: a menu is built as it opens and
/// cannot wait for the settings. Forget takes a template off a folder, with Undo.
@MainActor
@Observable
final class TemplateOriginsShown {
    /// The templates by folder, the one used last first; a folder that keeps none is absent.
    private(set) var templates: [FileItem.ID: [FolderTemplate]] = [:]

    /// Reads the templates of `folders`, beside those another window read.
    func read(_ folders: [FileItem.ID], browser: BrowserState) async {
        let origins = NameServices.templateOrigins(for: browser)
        for folder in folders {
            let kept = await origins.templates(madeFrom: folder)
            let read = kept.isEmpty ? nil : kept
            // Only a change is written, so the views that read it are not drawn again for
            // nothing each time a folder's contents show.
            if templates[folder] != read { templates[folder] = read }
        }
    }

    /// Forgets the template `id` of `folder`, or remembers it again, and registers the other
    /// for Undo, as the Mac's details pane does.
    func change(
        _ folder: FileItem.ID, template id: String, forgetting: Bool, browser: BrowserState,
        undoManager: UndoManager
    ) {
        undoManager.registerUndo(withTarget: self) { shown in
            shown.change(
                folder, template: id, forgetting: !forgetting, browser: browser,
                undoManager: undoManager)
        }
        undoManager.setActionName(String(localized: "Forget Template"))
        Task {
            let origins = NameServices.templateOrigins(for: browser)
            if forgetting {
                await origins.forget(id, madeFrom: folder)
            } else {
                await origins.remember(made: folder, from: id, yearBefore: nil)
            }
            await read([folder], browser: browser)
        }
    }
}
