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

    /// Creates settings.
    public init(enabledModules: [String], templates: [String: String]) {
        self.enabledModules = enabledModules
        self.templates = templates
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
