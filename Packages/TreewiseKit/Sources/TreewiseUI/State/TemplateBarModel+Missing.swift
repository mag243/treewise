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
        /// The year of the folder.
        public let year: Int
        /// The folder a year before read as a template, as the add-on recognizes it.
        public let recognized: FolderTree
        /// The folders missing.
        public let missing: MissingFolders
        /// The templates Add to Template adds to, each with the missing folders it lacks
        /// added: those the year's folder or the year before was made from, the one used last
        /// first (ADR 0141), or, when neither keeps one, the one template rooted at `{year}`;
        /// empty when there is none or none lacks them.
        public let templates: [FolderTemplate]
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
            folder: folder, yearBefore: before, year: year, recognized: recognized,
            missing: missing,
            templates: await templates(
                adding: missing, from: recognized, values: values,
                madeFrom: [folder.id, before]))
    }

    private func templates(
        adding missing: MissingFolders, from recognized: FolderTree, values: FolderTemplateValues,
        madeFrom folders: [FileItem.ID]
    ) async -> [FolderTemplate] {
        var kept: [FolderTemplate] = []
        for folder in folders {
            for template in await templates(madeFrom: folder) where !kept.contains(template) {
                kept.append(template)
            }
        }
        if kept.isEmpty {
            let rooted = await templates.templates().filter(\.isRootedAtYear)
            guard rooted.count == 1 else { return [] }
            kept = rooted
        }
        return kept.compactMap { template in
            guard let root = template.root.adding(missing, from: recognized, values: values)
            else { return nil }
            var added = template
            added.root = root
            return added
        }
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
