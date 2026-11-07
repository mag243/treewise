import TreewiseCore

/// A module as the app knows it, without running it (ADR 0057).
public struct NameModuleDescription: Hashable, Sendable, Codable {
    /// The id of the folder pattern module, the one that is on in a new folder.
    public static let defaultModuleID = "me.m-domain.treewise.folder-pattern"

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
    /// Whether it comes without paying, as Settings shows (ADR 0055, ADR 0070).
    public let isFree: Bool
    /// The name the app shows for it, or nil when the app names it itself.
    public let name: String?
    /// The ids of the modules it replaces, which the app then does not offer (ADR 0067).
    public let replaces: Set<String>

    /// Creates a description.
    public init(
        id: String, contentTypes: Set<String>, neededContent: Set<ModuleContentKind>,
        fields: [NameTemplate.Field], defaultTemplate: String, isFree: Bool = false,
        name: String? = nil, replaces: Set<String> = []
    ) {
        self.id = id
        self.contentTypes = contentTypes
        self.neededContent = neededContent
        self.fields = fields
        self.defaultTemplate = defaultTemplate
        self.isFree = isFree
        self.name = name
        self.replaces = replaces
    }

    /// Whether it plays the default module's part: on in a new folder, imposing no
    /// pattern on a folder that shows none. The default module does, and a module that
    /// replaces it (ADR 0067).
    public var takesTheDefaultModulesPart: Bool {
        id == Self.defaultModuleID || replaces.contains(Self.defaultModuleID)
    }

    /// The modules the app offers, in the order given: those no other module replaces.
    public static func offered(_ all: [NameModuleDescription]) -> [NameModuleDescription] {
        let replaced = Set(all.filter { !$0.replaces.isEmpty }.flatMap(\.replaces))
        return all.filter { !replaced.contains($0.id) }
    }

    /// The id that plays the default module's part among offered modules: the module
    /// that replaces it, or the default module's own id.
    public static func defaultID(among offered: [NameModuleDescription]) -> String {
        offered.first { $0.takesTheDefaultModulesPart }?.id ?? defaultModuleID
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
    func derivedTemplate(moduleID: String, names: [String], folderName: String) async throws
        -> String?
}
