import Foundation
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
    /// Where it can be bought, for a paid module (ADR 0071).
    public let purchaseURL: String?
    /// What it does, in one line, by language code (`en`, `nl`, `de`): a closed module
    /// brings its own words, as the open app does not know it (ADR 0088).
    public let summaries: [String: String]
    /// What it finds by itself in a folder's names, written as in a pattern, as `{date}`,
    /// `{seq:4}` or `<…|…>` (ADR 0088).
    public let recognizes: [String]

    /// Creates a description.
    public init(
        id: String, contentTypes: Set<String>, neededContent: Set<ModuleContentKind>,
        fields: [NameTemplate.Field], defaultTemplate: String, isFree: Bool = false,
        name: String? = nil, replaces: Set<String> = [], purchaseURL: String? = nil,
        summaries: [String: String] = [:], recognizes: [String] = []
    ) {
        self.id = id
        self.contentTypes = contentTypes
        self.neededContent = neededContent
        self.fields = fields
        self.defaultTemplate = defaultTemplate
        self.isFree = isFree
        self.name = name
        self.replaces = replaces
        self.purchaseURL = purchaseURL
        self.summaries = summaries
        self.recognizes = recognizes
    }

    /// What it does, in the first of the languages it has a summary in, by their codes as
    /// `Locale.preferredLanguages` gives them (`nl-NL`), else in English; nil when it has
    /// none.
    public func summary(preferring languages: [String]) -> String? {
        for language in languages {
            let code = language.split(separator: "-").first.map(String.init) ?? language
            if let summary = summaries[code] { return summary }
        }
        return summaries["en"]
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
    /// Asks a module which templates a folder's names might follow, the best first; none
    /// when it recognizes none (ADR 0067).
    func derivedTemplates(
        moduleID: String, names: [String], folderName: String, licence: LicenceContext
    ) async throws -> [String]
    /// Asks a module what its licence lets it do; nil when it needs no licence (ADR 0071).
    func licenceState(moduleID: String, licence: LicenceContext) async throws
        -> ModuleLicenceState?
}
