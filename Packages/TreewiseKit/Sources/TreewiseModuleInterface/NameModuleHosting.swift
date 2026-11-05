import TreewiseCore

/// A module as the app knows it, without running it (ADR 0057).
public struct NameModuleDescription: Hashable, Sendable, Codable {
    /// The id of the free module, the one that is on in a new folder.
    public static let freeModuleID = "me.m-domain.treewise.folder-pattern"

    /// The module's id.
    public let id: String
    /// The uniform type identifiers it handles, each with its subtypes. Other files
    /// are never sent to it.
    public let contentTypes: Set<String>
    /// The content its requests must hold.
    public let neededContent: Set<ModuleContentKind>
    /// The fields its values can fill, besides `NameTemplate.Field.folder`.
    public let fields: [NameTemplate.Field]
    /// The template it starts from, until the user changes it.
    public let defaultTemplate: String

    /// Creates a description.
    public init(
        id: String, contentTypes: Set<String>, neededContent: Set<ModuleContentKind>,
        fields: [NameTemplate.Field], defaultTemplate: String
    ) {
        self.id = id
        self.contentTypes = contentTypes
        self.neededContent = neededContent
        self.fields = fields
        self.defaultTemplate = defaultTemplate
    }
}

/// Why a module gave no answer. None of this stops the app: it goes on with the
/// proposals it has (ADR 0057).
public enum NameModuleHostError: Error, Hashable, Sendable {
    /// The modules' process could not be reached, or stopped.
    case unavailable
    /// No answer came in time.
    case timedOut
    /// The module failed, or is not known.
    case moduleFailed
    /// The answer was too large or could not be read.
    case invalidResponse
}

/// Where the app reaches its modules, wherever they run (ADR 0057).
public protocol NameModuleHosting: Sendable {
    /// The modules on offer.
    func availableModules() async throws -> [NameModuleDescription]
    /// Asks a module for ranked sets of values. A request must hold only what the
    /// module declared.
    func fieldValues(moduleID: String, request: NameRequest) async throws
        -> [[String: NameTemplate.Value]]
    /// Asks a module which template a folder's names follow; nil when it recognizes none.
    func derivedTemplate(moduleID: String, names: [String]) async throws -> String?
}
