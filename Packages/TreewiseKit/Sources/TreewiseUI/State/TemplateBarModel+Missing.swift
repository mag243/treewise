import Foundation
import TreewiseCore

/// The folders of the year before that a year's folder lacks (ADR 0102): offered in the bar
/// of a year's folder that holds items, and by Add Missing Folders… in the menus.
extension TemplateBarModel {
    /// What a year's folder lacks of the year before.
    public struct MissingOffer: Hashable, Sendable {
        /// The year's folder.
        public let folder: FileItem
        /// The same folder a year before.
        public let yearBefore: FileItem.ID
        /// The folders missing.
        public let missing: MissingFolders
        /// The one template rooted at `{year}` with the missing folders it lacks added, or
        /// nil when there is no such template or it lacks none.
        public let template: FolderTemplate?
    }

    /// What `folder` lacks of the year before, while the add-on may work; nil when nothing
    /// is missing or `folder` is no year's own. For the bar, `all` false, only in a folder
    /// that holds items, while Settings offers them, and without the folders closed; for
    /// the menus, `all` true, every folder missing.
    public func missing(in folder: FileItem, all: Bool = false) async -> MissingOffer? {
        guard folder.kind == .folder, let year = YearFolders.ownYear(of: folder.id),
            let before = YearFolders.folderBefore(folder.id), await addOnMayWork()
        else { return nil }
        var closed: Set<[String]> = []
        if !all {
            let own = await settings.settings(forFolderAt: folder.id.rawValue)
            guard offersMissingFolders(), own?.offersNoMissingFolders != true,
                let items = try? await fileSystem.contents(of: folder.id),
                !items.allSatisfy(\.isHidden)
            else { return nil }
            closed = own?.missingFoldersClosed ?? []
        }
        guard let recognized = await yearBefore(before) else { return nil }
        let values = FolderTemplateValues(year: year)
        let made = recognized.filling(folderNamed: folder.name).filling(values)
        guard let there = try? await fileSystem.folderContents(for: made, in: folder.id) else {
            return nil
        }
        let missing = MissingFolders(of: made, in: there, leavingOut: closed)
        guard !missing.isEmpty else { return nil }
        return MissingOffer(
            folder: folder, yearBefore: before, missing: missing,
            template: await template(adding: missing, from: recognized, values: values))
    }

    private func template(
        adding missing: MissingFolders, from recognized: FolderTree, values: FolderTemplateValues
    ) async -> FolderTemplate? {
        let rooted = await templates.templates().filter(\.isRootedAtYear)
        guard rooted.count == 1, var template = rooted.first,
            let root = template.root.adding(missing, from: recognized, values: values)
        else { return nil }
        template.root = root
        return template
    }

    /// Don’t Show These Folders: the bar leaves out the folders `offer` holds from then on.
    public func closeMissing(_ offer: MissingOffer) async {
        await change(offer.folder.id) { $0.missingFoldersClosed.formUnion(offer.missing.paths) }
    }

    /// Don't Show for This Folder: the bar offers `folder` no missing folders at all.
    public func offerNoMissing(in folder: FileItem.ID) async {
        await change(folder) { $0.offersNoMissingFolders = true }
    }
}
