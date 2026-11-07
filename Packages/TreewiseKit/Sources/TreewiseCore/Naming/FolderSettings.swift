/// Where the settings of folders are kept.
public protocol FolderSettingsStoring: Sendable {
    /// The settings of the folder at a path, or nil when it has none.
    func settings(forFolderAt path: String) async -> FolderSettings?
    /// Saves the settings of the folder at a path.
    func save(_ settings: FolderSettings, forFolderAt path: String) async
}

/// What the user chose for a folder: which modules are on and each module's template
/// (ADR 0057). Treewise keeps this in its own folder; the folder holds only a random id.
public struct FolderSettings: Hashable, Sendable, Codable {
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
        moduleOrder.filter(catalog.contains) + catalog.filter { !moduleOrder.contains($0) }
    }

    /// Moves a module to a place in the order of `catalog`, and the modules that are on
    /// follow it.
    public mutating func moveModule(_ id: String, to index: Int, catalog: [String]) {
        var order = ordered(catalog)
        guard let from = order.firstIndex(of: id) else { return }
        order.remove(at: from)
        order.insert(id, at: min(max(0, index), order.count))
        moduleOrder = order
        enabledModules = Self.inOrder(Set(enabledModules), order, after: enabledModules)
    }

    /// Gives what was chosen for a module to the module that replaces it (ADR 0067): whether
    /// it is on, its pattern unless the other has one of its own, and its place in the
    /// order.
    public mutating func handOver(from replaced: String, to replacing: String) {
        var enabled: [String] = []
        for id in enabledModules.map({ $0 == replaced ? replacing : $0 })
        where !enabled.contains(id) {
            enabled.append(id)
        }
        enabledModules = enabled
        if let pattern = templates.removeValue(forKey: replaced), templates[replacing] == nil {
            templates[replacing] = pattern
            savedPatternLinks[replacing] = savedPatternLinks[replaced]
        }
        savedPatternLinks[replaced] = nil
        var order: [String] = []
        for id in moduleOrder.map({ $0 == replaced ? replacing : $0 }) where !order.contains(id) {
            order.append(id)
        }
        moduleOrder = order
    }

    /// Creates settings.
    public init(enabledModules: [String], templates: [String: String]) {
        self.enabledModules = enabledModules
        self.templates = templates
    }

    private enum CodingKeys: String, CodingKey {
        case enabledModules, templates, alwaysSkipped, moduleOrder, savedPatternLinks
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
