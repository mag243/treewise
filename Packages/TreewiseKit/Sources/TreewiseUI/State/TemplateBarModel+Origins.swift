import Foundation
import TreewiseCore

/// The templates a folder was made from (ADR 0141), kept by the folder a template fills or
/// makes as its root, so the template corrected and added to is the one it came from.
extension TemplateBarModel {
    /// Notes that `folder` was made from the template `templateID`, or, made from the
    /// folder `yearBefore`, from the templates that one was made from.
    public func remember(
        made folder: FileItem.ID, from templateID: String?, yearBefore: FileItem.ID?
    ) async {
        var ids = templateID.map { [$0] } ?? []
        if let yearBefore {
            let before = await settings.settings(forFolderAt: yearBefore.rawValue)
            ids = (before?.madeFrom ?? []) + ids
        }
        guard !ids.isEmpty else { return }
        await change(folder) { settings in
            for id in ids { settings.remember(madeFrom: id) }
        }
    }

    /// The templates `folder` was made from that are still here, the one used last first.
    public func templates(madeFrom folder: FileItem.ID) async -> [FolderTemplate] {
        guard let ids = await settings.settings(forFolderAt: folder.rawValue)?.madeFrom,
            !ids.isEmpty
        else { return [] }
        let here = await templates.templates()
        return ids.reversed().compactMap { id in here.first { $0.id == id } }
    }

    /// Forget, in the details pane: `folder` was not made from the template `templateID`.
    public func forget(_ templateID: String, madeFrom folder: FileItem.ID) async {
        await change(folder) { $0.forget(madeFrom: templateID) }
    }
}
