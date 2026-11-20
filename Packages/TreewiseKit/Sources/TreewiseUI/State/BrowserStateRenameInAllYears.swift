import Foundation
import TreewiseCore

/// What Rename in All Years did (ADR 0139).
public enum RenameInAllYearsResult: Sendable {
    /// Nothing was renamed, nor tried.
    case nothing
    /// Every checked folder has its new name.
    case renamed(count: Int)
    /// It stopped at a folder: those before it have their new name and one Undo takes them
    /// back; the templates and closed missing folders are as they were.
    case stopped(BatchRenameOutcome.Failure, renamed: Int)
}

extension BrowserState {
    /// Gives the folders `model` checked its new name in one step, corrects its templates
    /// and closes the years' closed missing folders under the new name too, and registers
    /// one Undo for all of it (ADR 0139). A failure is the caller's to show.
    @discardableResult
    public func renameInAllYears(
        _ model: RenameInAllYearsModel, templates: FolderTemplatesModel,
        settings: any FolderSettingsStoring, undoManager: UndoManager?
    ) async -> RenameInAllYearsResult {
        guard let operations, model.canRename else { return .nothing }
        let names = Dictionary(
            model.places.map { ($0.parent, $0.namesBeside) },
            uniquingKeysWith: { first, _ in first })
        guard case .ready(let steps) = BatchRenamePlanner.plan(model.renames, namesInFolders: names)
        else { return .nothing }
        let outcome = await operations.applyBatch(steps)
        if !outcome.renamed.isEmpty {
            let alongside =
                outcome.failure == nil
                ? await changeAlongside(model, templates: templates, settings: settings) : nil
            registerUndo(
                Task { outcome.undo }, name: Self.actionName("Rename in All Years"),
                undoManager: undoManager, alongside: alongside)
            await relocateFavorites(outcome.renamed.map { ($0.original, $0.item.id) })
            await reloadShownFolders()
        }
        guard let failure = outcome.failure else { return .renamed(count: outcome.renamed.count) }
        return .stopped(failure, renamed: outcome.renamed.count)
    }

    /// Corrects the templates and closes the years' closed missing folders under the new
    /// name too, and returns how to undo and redo that.
    private func changeAlongside(
        _ model: RenameInAllYearsModel, templates: FolderTemplatesModel,
        settings: any FolderSettingsStoring
    ) async -> UndoAlongside {
        let corrected = model.correctedTemplates
        let originals = model.templates.filter { template in
            corrected.contains { $0.id == template.id }
        }
        var closing: [FileItem.ID: Set<[String]>] = [:]
        for year in model.years {
            let kept = await settings.settings(forFolderAt: year.rawValue)
            let added = kept?.closedMissing(renamedAt: model.path, to: model.trimmedName) ?? []
            if !added.isEmpty { closing[year] = added }
        }
        let closed = closing
        let forward: @MainActor @Sendable () async -> Void = {
            await templates.replace(corrected)
            await Self.change(closed, settings: settings) { $0.formUnion($1) }
        }
        let backward: @MainActor @Sendable () async -> Void = {
            await templates.replace(originals)
            await Self.change(closed, settings: settings) { $0.subtract($1) }
        }
        await forward()
        return UndoAlongside(undo: backward, redo: forward)
    }

    /// Changes each year's closed missing folders by `change` with its paths in `paths`.
    private static func change(
        _ paths: [FileItem.ID: Set<[String]>], settings: any FolderSettingsStoring,
        by change: (inout Set<[String]>, Set<[String]>) -> Void
    ) async {
        for (year, added) in paths {
            guard var kept = await settings.settings(forFolderAt: year.rawValue) else { continue }
            change(&kept.missingFoldersClosed, added)
            await settings.save(kept, forFolderAt: year.rawValue)
        }
    }
}
