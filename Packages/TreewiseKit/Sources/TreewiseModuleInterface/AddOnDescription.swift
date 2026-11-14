import Foundation
import TreewiseCore

/// An add-on as the app knows it, without running it, whatever its kind (ADR 0057,
/// ADR 0098): what the catalog, the Add-ons tab and licences need, and its kind with what
/// that kind needs.
public struct AddOnDescription: Hashable, Sendable, Codable {
    /// What an add-on does, with what doing it needs.
    public enum Kind: Hashable, Sendable, Codable {
        /// It proposes names for files and folders (ADR 0057).
        case names(NameCapabilities)
        /// It makes the template of a folder's structure, and the folders a template makes
        /// (ADR 0091).
        case folderStructure
    }

    /// The id of the folder pattern module, the one that is on in a new folder.
    public static let defaultModuleID = "me.m-domain.treewise.folder-pattern"

    /// The add-on's id.
    public let id: String
    /// The name the app shows for it, or nil when the app names it itself.
    public let name: String?
    /// Whether it comes without paying, as Settings shows (ADR 0055, ADR 0070).
    public let isFree: Bool
    /// Where it can be bought, for a paid add-on (ADR 0071).
    public let purchaseURL: String?
    /// What it does, in one line, by language code (`en`, `nl`, `de`): a closed add-on
    /// brings its own words, as the open app does not know it (ADR 0088).
    public let summaries: [String: String]
    /// What it finds by itself, written as in a pattern, as `{date}`, `{seq:4}` or `{year}`
    /// (ADR 0088).
    public let recognizes: [String]
    /// What it does.
    public let kind: Kind

    /// Describes an add-on of any kind.
    public init(
        id: String, name: String? = nil, isFree: Bool = false, purchaseURL: String? = nil,
        summaries: [String: String] = [:], recognizes: [String] = [], kind: Kind
    ) {
        self.id = id
        self.name = name
        self.isFree = isFree
        self.purchaseURL = purchaseURL
        self.summaries = summaries
        self.recognizes = recognizes
        self.kind = kind
    }

    /// Describes an add-on that proposes names.
    public init(
        id: String, contentTypes: Set<String>, neededContent: Set<ModuleContentKind>,
        fields: [NameTemplate.Field], defaultTemplate: String, isFree: Bool = false,
        name: String? = nil, replaces: Set<String> = [], purchaseURL: String? = nil,
        summaries: [String: String] = [:], recognizes: [String] = [],
        readsYearBefore: Bool = false
    ) {
        self.init(
            id: id, name: name, isFree: isFree, purchaseURL: purchaseURL, summaries: summaries,
            recognizes: recognizes,
            kind: .names(
                NameCapabilities(
                    contentTypes: contentTypes, neededContent: neededContent, fields: fields,
                    defaultTemplate: defaultTemplate, replaces: replaces,
                    readsYearBefore: readsYearBefore)))
    }

    /// Whether it proposes names.
    public var proposesNames: Bool {
        if case .names = kind { true } else { false }
    }

    /// Whether it makes folder structures.
    public var makesFolderStructures: Bool { kind == .folderStructure }

    /// What it needs and offers for names; `NameCapabilities.none` for an add-on of another
    /// kind, which the app never asks for names.
    public var names: NameCapabilities {
        if case .names(let capabilities) = kind { capabilities } else { .none }
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
        proposesNames
            && (id == Self.defaultModuleID || names.replaces.contains(Self.defaultModuleID))
    }

    /// The add-ons the app offers, in the order given: those no other add-on replaces.
    public static func offered(_ all: [AddOnDescription]) -> [AddOnDescription] {
        let replaced = Set(all.flatMap(\.names.replaces))
        return all.filter { !replaced.contains($0.id) }
    }

    /// The add-ons the app offers for proposing names: those of `offered(_:)` that propose
    /// names, never an add-on that makes folder structures (ADR 0091).
    public static func offered(forNames all: [AddOnDescription]) -> [AddOnDescription] {
        offered(all.filter(\.proposesNames))
    }

    /// The id that plays the default module's part among offered add-ons: the one that
    /// replaces it, or the default module's own id.
    public static func defaultID(among offered: [AddOnDescription]) -> String {
        offered.first { $0.takesTheDefaultModulesPart }?.id ?? defaultModuleID
    }
}
