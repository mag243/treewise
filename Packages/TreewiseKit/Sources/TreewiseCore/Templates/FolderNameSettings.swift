/// The name settings a template keeps for one of its folders (ADR 0101): the add-ons that
/// are on, the user's order of the add-ons and each add-on's pattern as text. A link to a
/// saved pattern, the files always skipped and what the folder offers for new folders stay
/// with the folder itself, as they name things of this Mac or of that one folder.
public struct FolderNameSettings: Codable, Hashable, Sendable {
    /// The ids of the add-ons that are on, in their order.
    public var enabledModules: [String]
    /// The user's order of the add-ons, those that are off included; empty when the
    /// catalog's order counts (ADR 0065).
    public var moduleOrder: [String]
    /// The pattern of each add-on whose pattern differs from its default, by add-on id.
    public var patterns: [String: String]

    /// Creates name settings.
    public init(enabledModules: [String], moduleOrder: [String], patterns: [String: String]) {
        self.enabledModules = enabledModules
        self.moduleOrder = moduleOrder
        self.patterns = patterns
    }

    /// The name settings of a folder's settings, or nil when the folder was never reviewed.
    public init?(_ settings: FolderSettings?) {
        guard let settings, settings.isReviewed else { return nil }
        self.init(
            enabledModules: settings.enabledModules, moduleOrder: settings.moduleOrder,
            patterns: settings.templates)
    }

    /// Reads name settings; those stored without an order or patterns get none.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabledModules = try container.decode([String].self, forKey: .enabledModules)
        moduleOrder = try container.decodeIfPresent([String].self, forKey: .moduleOrder) ?? []
        patterns = try container.decodeIfPresent([String: String].self, forKey: .patterns) ?? [:]
    }

    /// The settings a folder made from the template gets, with only the add-ons `catalog`
    /// holds, or nil when none of those that are on is left.
    public func folderSettings(catalog: Set<String>) -> FolderSettings? {
        let enabled = enabledModules.filter(catalog.contains)
        guard !enabled.isEmpty else { return nil }
        var settings = FolderSettings(
            enabledModules: enabled, templates: patterns.filter { catalog.contains($0.key) })
        settings.moduleOrder = moduleOrder.filter(catalog.contains)
        return settings
    }
}

extension FolderSettingsStoring {
    /// Gives each folder made from `tree`, by its path from the root as
    /// `FolderTemplateOutcome.made` holds it, the name settings the tree keeps for it, unless
    /// the folder has settings of its own already (ADR 0101).
    public func give(
        namesOf tree: FolderTree, to made: [[String]: FileItem.ID], catalog: Set<String>
    ) async {
        for (path, names) in tree.namesByPath {
            guard let folder = made[path], let given = names.folderSettings(catalog: catalog),
                await settings(forFolderAt: folder.rawValue) == nil
            else { continue }
            await save(given, forFolderAt: folder.rawValue)
        }
    }

    /// The name settings of `folder`, for reading a tree with them (ADR 0101).
    public func names(of folder: FileItem) async -> FolderNameSettings? {
        FolderNameSettings(await settings(forFolderAt: folder.id.rawValue))
    }
}
