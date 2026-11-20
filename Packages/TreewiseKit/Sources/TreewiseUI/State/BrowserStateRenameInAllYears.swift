import Foundation
import TreewiseCore

extension BrowserState {
    /// Gives the folders `model` checked its new name in one step, corrects its templates
    /// and the years' closed missing folders along, and registers one Undo for all of it
    /// (ADR 0139). Returns why it stopped, if it did: then what was renamed stays renamed
    /// and can be undone, and the templates and closed missing folders are left as they were.
    @discardableResult
    public func renameInAllYears(
        _ model: RenameInAllYearsModel, templates: FolderTemplatesModel,
        settings: any FolderSettingsStoring, undoManager: UndoManager?
    ) async -> BatchRenameOutcome.Failure? {
        guard let operations, model.canRename else { return nil }
        let renames = model.renames
        let names = Dictionary(
            model.places.map { ($0.parent, $0.namesBeside) },
            uniquingKeysWith: { first, _ in first })
        guard case .ready(let steps) = BatchRenamePlanner.plan(renames, namesInFolders: names)
        else { return nil }
        let outcome = await operations.applyBatch(steps)
        guard !outcome.renamed.isEmpty || outcome.failure != nil else { return nil }
        let alongside =
            outcome.failure == nil
            ? await changeAlongside(model, templates: templates, settings: settings) : nil
        registerUndo(
            Task { outcome.undo }, name: Self.actionName("Rename in All Years"),
            undoManager: undoManager, alongside: alongside)
        await relocateFavorites(outcome.renamed.map { ($0.original, $0.item.id) })
        await reloadShownFolders()
        if let failure = outcome.failure { self.failure = failure.error }
        return outcome.failure
    }

    /// Corrects the templates and the years' closed missing folders, and returns how to undo
    /// and redo that.
    private func changeAlongside(
        _ model: RenameInAllYearsModel, templates: FolderTemplatesModel,
        settings: any FolderSettingsStoring
    ) async -> UndoAlongside {
        let corrected = model.correctedTemplates
        let originals = model.templates.filter { template in
            corrected.contains { $0.id == template.id }
        }
        let years = model.years
        let oldPath = model.path
        let newPath = oldPath.dropLast() + [model.trimmedName]
        let (oldName, newName) = (model.oldName, model.trimmedName)
        let forward: @MainActor @Sendable () async -> Void = {
            await templates.replace(corrected)
            await Self.renameClosed(at: oldPath, to: newName, in: years, settings: settings)
        }
        let backward: @MainActor @Sendable () async -> Void = {
            await templates.replace(originals)
            await Self.renameClosed(at: Array(newPath), to: oldName, in: years, settings: settings)
        }
        await forward()
        return UndoAlongside(undo: backward, redo: forward)
    }

    private static func renameClosed(
        at path: [String], to name: String, in years: [FileItem.ID],
        settings: any FolderSettingsStoring
    ) async {
        for year in years {
            guard var kept = await settings.settings(forFolderAt: year.rawValue),
                !kept.missingFoldersClosed.isEmpty
            else { continue }
            let before = kept.missingFoldersClosed
            kept.renameClosedMissing(at: path, to: name)
            if kept.missingFoldersClosed != before {
                await settings.save(kept, forFolderAt: year.rawValue)
            }
        }
    }
}
