/// Whether an empty folder offers a template's folders in a bar above its list, and from
/// where (ADR 0094, ADR 0097).
public enum TemplateBarRule {
    /// Where the folders offered come from.
    public enum Source: Hashable, Sendable {
        /// The same folder a year before, read as a template.
        case yearBefore(FileItem.ID)
        /// A saved template.
        case template(FolderTemplate)
    }

    /// What the rule knows of the folder that is open.
    public struct Folder: Hashable, Sendable {
        /// The folder.
        public let id: FileItem.ID
        /// Whether it holds nothing but hidden items.
        public let holdsOnlyHiddenItems: Bool
        /// Its own settings, which say whether its bar was closed.
        public let settings: FolderSettings?
        /// The settings of the folder that holds it, which say what its empty folders are
        /// offered.
        public let settingsAbove: FolderSettings?
        /// Whether `YearFolders.folderBefore(id)` holds folders.
        public let yearBeforeHasFolders: Bool

        /// What is known of a folder.
        public init(
            id: FileItem.ID, holdsOnlyHiddenItems: Bool, settings: FolderSettings?,
            settingsAbove: FolderSettings?, yearBeforeHasFolders: Bool
        ) {
            self.id = id
            self.holdsOnlyHiddenItems = holdsOnlyHiddenItems
            self.settings = settings
            self.settingsAbove = settingsAbove
            self.yearBeforeHasFolders = yearBeforeHasFolders
        }
    }

    /// The source of the bar for `folder`, or nil when it shows none.
    ///
    /// It shows while the add-on may work, in a folder that holds nothing but hidden items
    /// and was not closed for. The folder above it decides first: None offers nothing, and
    /// a template chosen there is offered when it still exists. Otherwise, in a folder with
    /// a year in its path, the same folder a year before when it holds folders, else the one
    /// template rooted at `{year}` when the folder itself is a year's.
    public static func source(
        for folder: Folder, addOnMayWork: Bool, templates: [FolderTemplate]
    ) -> Source? {
        guard addOnMayWork, folder.holdsOnlyHiddenItems, folder.settings?.templateBarClosed != true
        else { return nil }
        switch folder.settingsAbove?.newFolders ?? .automatic {
        case .none:
            return nil
        case .template(let id):
            if let chosen = templates.first(where: { $0.id == id }) { return .template(chosen) }
        case .automatic:
            break
        }
        return automatic(
            for: folder.id, yearBeforeHasFolders: folder.yearBeforeHasFolders, templates)
    }

    private static func automatic(
        for folder: FileItem.ID, yearBeforeHasFolders: Bool, _ templates: [FolderTemplate]
    ) -> Source? {
        guard let before = YearFolders.folderBefore(folder) else { return nil }
        if yearBeforeHasFolders { return .yearBefore(before) }
        let ownName = folder.rawValue.split(separator: "/").last.map(String.init)
        guard let year = YearFolders.year(of: folder), ownName == String(year) else {
            return nil
        }
        let rooted = templates.filter(\.isRootedAtYear)
        return rooted.count == 1 ? rooted.first.map(Source.template) : nil
    }
}
