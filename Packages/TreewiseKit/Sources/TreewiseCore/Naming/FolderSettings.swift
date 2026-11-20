/// Where the settings of folders are kept.
public protocol FolderSettingsStoring: Sendable {
    /// The settings of the folder at a path, or nil when it has none.
    func settings(forFolderAt path: String) async -> FolderSettings?
    /// Saves the settings of the folder at a path.
    func save(_ settings: FolderSettings, forFolderAt path: String) async
}

/// What the user chose for a folder: which modules are on and each module's template
/// (ADR 0057), and what is offered of folder templates (ADR 0094, ADR 0097). Treewise keeps
/// this in its own folder; the folder holds only a random id.
public struct FolderSettings: Hashable, Sendable, Codable {
    /// What the empty folders made in a folder are offered (ADR 0097).
    public enum NewFolders: Hashable, Sendable, Codable {
        /// The folder a year before, or the one template rooted at `{year}` (ADR 0094).
        case automatic
        /// The template with this id.
        case template(id: String)
        /// Nothing.
        case none
    }

    /// How an id found on a folder relates to what Treewise recorded.
    public enum Place: Hashable, Sendable {
        /// The folder has no id.
        case noID
        /// Nothing is recorded for the id: it comes from another Treewise.
        case unknownID
        /// The folder is where it was recorded.
        case same
        /// The folder has moved, or was renamed.
        case moved
        /// A folder with the same id is still at the recorded path, so this is a copy.
        case copy
    }

    /// The ids of the modules that are on, in their order.
    public var enabledModules: [String]
    /// The template of each module whose template differs from its default, by module id.
    public var templates: [String: String]
    /// The names, on disk, of the files a whole-folder review always skips.
    public var alwaysSkipped: Set<String> = []
    /// The user's order of the modules, those that are off included (ADR 0065); empty
    /// until the user changes it, when the catalog's order counts.
    public var moduleOrder: [String] = []
    /// The saved pattern each module's template was picked from, by module id (ADR 0068).
    public var savedPatternLinks: [String: SavedPatternLink] = [:]
    /// What the empty folders in this folder are offered (ADR 0097).
    public var newFolders = NewFolders.automatic
    /// Whether the bar offering a template's folders was closed for this folder (ADR 0094).
    public var templateBarClosed = false
    /// The folders of the year before that the bar leaves out in this year’s folder,
    /// by their path below it, as they were missing when it was closed (ADR 0102).
    public var missingFoldersClosed: Set<[String]> = []
    /// Whether the bar offers this year's folder no missing folders at all (ADR 0102).
    public var offersNoMissingFolders = false
    /// The names the bar does not take for one folder in this year's folder, after Add
    /// Anyway (ADR 0139): each the path of the folder that holds them below this one, then
    /// the two names as the file system compares them, in order.
    public var namesKeptApart: Set<[String]> = []
    /// The ids of the templates this folder was made from, the one used last last (ADR
    /// 0141): kept by the folder a template fills or makes as its root.
    public var madeFrom: [String] = []

    /// Notes that this folder was made from, or corrected through, the template `id`.
    public mutating func remember(madeFrom id: String) {
        madeFrom.removeAll { $0 == id }
        madeFrom.append(id)
    }

    /// Forgets that this folder was made from the template `id`.
    public mutating func forget(madeFrom id: String) {
        madeFrom.removeAll { $0 == id }
    }

    /// The entry of `namesKeptApart` for `one` and `other` in the folder at `place`.
    public static func keptApart(_ one: String, _ other: String, at place: [String])
        -> [String]
    {
        place.map(ConflictResolver.comparisonKey)
            + [one, other].map(ConflictResolver.comparisonKey).sorted()
    }

    /// Takes what `other` says of templates (ADR 0094, ADR 0097, ADR 0102), which changes
    /// outside the review, keeping the rest of these settings.
    public mutating func keepTemplates(of other: FolderSettings) {
        newFolders = other.newFolders
        templateBarClosed = other.templateBarClosed
        missingFoldersClosed = other.missingFoldersClosed
        offersNoMissingFolders = other.offersNoMissingFolders
        namesKeptApart = other.namesKeptApart
        madeFrom = other.madeFrom
    }

    /// Whether the folder was ever reviewed: then a module is on, which a folder kept only
    /// for what it says of templates has not.
    public var isReviewed: Bool { !enabledModules.isEmpty }

    /// The settings of a folder reviewed for the first time.
    public static func new(defaultModuleID: String) -> FolderSettings {
        FolderSettings(enabledModules: [defaultModuleID], templates: [:])
    }

    /// Turns a module on or off, keeping `order`; modules on that `order` does not hold, as
    /// one turned off in Settings, stay on after them. Invariant: at least one stays on.
    public mutating func setModule(_ id: String, on: Bool, order: [String]) {
        var enabled = Set(enabledModules)
        if on { enabled.insert(id) } else { enabled.remove(id) }
        guard !enabled.isEmpty else { return }
        enabledModules = Self.inOrder(enabled, order, after: enabledModules)
    }

    /// The modules of `enabled` in `order`, then those `order` does not hold, as `before`
    /// had them.
    private static func inOrder(_ enabled: Set<String>, _ order: [String], after before: [String])
        -> [String]
    {
        order.filter(enabled.contains)
            + before.filter { enabled.contains($0) && !order.contains($0) }
    }

    /// The modules of `catalog` in the user's order: those the user ordered first, then
    /// the rest in the catalog's order, so a module new to the folder comes last.
    public func ordered(_ catalog: [String]) -> [String] {
        UserOrder.ordered(moduleOrder, catalog)
    }

    /// Moves a module to a place in the order of `catalog`, and the modules that are on
    /// follow it.
    public mutating func moveModule(_ id: String, to index: Int, catalog: [String]) {
        guard let order = UserOrder.moving(id, to: index, in: moduleOrder, catalog: catalog)
        else { return }
        moduleOrder = order
        enabledModules = Self.inOrder(Set(enabledModules), order, after: enabledModules)
    }

    /// Gives what was chosen for a module to the module that replaces it (ADR 0067): whether
    /// it is on, its pattern unless the other has one of its own, and its place in the
    /// order.
    public mutating func handOver(from replaced: String, to replacing: String) {
        enabledModules = UserOrder.replacing(replaced, with: replacing, in: enabledModules)
        if let pattern = templates.removeValue(forKey: replaced), templates[replacing] == nil {
            templates[replacing] = pattern
            savedPatternLinks[replacing] = savedPatternLinks[replaced]
        }
        savedPatternLinks[replaced] = nil
        moduleOrder = UserOrder.replacing(replaced, with: replacing, in: moduleOrder)
    }

    /// Creates settings.
    public init(enabledModules: [String], templates: [String: String]) {
        self.enabledModules = enabledModules
        self.templates = templates
    }

    private enum CodingKeys: String, CodingKey {
        case enabledModules, templates, alwaysSkipped, moduleOrder, savedPatternLinks
        case newFolders, templateBarClosed, missingFoldersClosed, offersNoMissingFolders
        case namesKeptApart, madeFrom
    }

    /// Reads settings; those stored before a field existed get its default.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabledModules = try container.decode([String].self, forKey: .enabledModules)
        templates = try container.decode([String: String].self, forKey: .templates)
        alwaysSkipped =
            try container.decodeIfPresent(Set<String>.self, forKey: .alwaysSkipped) ?? []
        moduleOrder = try container.decodeIfPresent([String].self, forKey: .moduleOrder) ?? []
        savedPatternLinks =
            try container.decodeIfPresent(
                [String: SavedPatternLink].self, forKey: .savedPatternLinks) ?? [:]
        newFolders =
            try container.decodeIfPresent(NewFolders.self, forKey: .newFolders) ?? .automatic
        templateBarClosed =
            try container.decodeIfPresent(Bool.self, forKey: .templateBarClosed) ?? false
        missingFoldersClosed =
            try container.decodeIfPresent(Set<[String]>.self, forKey: .missingFoldersClosed) ?? []
        offersNoMissingFolders =
            try container.decodeIfPresent(Bool.self, forKey: .offersNoMissingFolders) ?? false
        namesKeptApart =
            try container.decodeIfPresent(Set<[String]>.self, forKey: .namesKeptApart) ?? []
        madeFrom = try container.decodeIfPresent([String].self, forKey: .madeFrom) ?? []
        // Settings kept under an add-on's former id belong to its current one (ADR 0140).
        AddOnIDs.convert { handOver(from: $0, to: $1) }
    }

    /// Decides how a folder relates to the record of the id on it.
    ///
    /// - Parameters:
    ///   - idOnFolder: The id on the folder, if it has one.
    ///   - path: Where the folder is now.
    ///   - recordedPath: The last path recorded for that id, if there is a record.
    ///   - idAtRecordedPath: The id on whatever is at that path now.
    public static func place(
        idOnFolder: String?, path: String, recordedPath: String?, idAtRecordedPath: String?
    ) -> Place {
        guard let idOnFolder else { return .noID }
        guard let recordedPath else { return .unknownID }
        if recordedPath == path { return .same }
        return idAtRecordedPath == idOnFolder ? .copy : .moved
    }
}
