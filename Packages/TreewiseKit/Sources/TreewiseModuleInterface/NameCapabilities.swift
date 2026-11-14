import TreewiseCore

/// What an add-on that proposes names needs and offers, beside what every add-on has
/// (ADR 0057, ADR 0098).
public struct NameCapabilities: Hashable, Sendable, Codable {
    /// What an add-on of another kind has for names: nothing.
    public static let none = NameCapabilities(
        contentTypes: [], neededContent: [], fields: [], defaultTemplate: "")

    /// The uniform type identifiers it handles, each with its subtypes. Other files
    /// are never sent to it.
    public let contentTypes: Set<String>
    /// The content its requests must hold.
    public let neededContent: Set<ModuleContentKind>
    /// The fields its values can fill, besides `NameTemplate.Field.folder`.
    public let fields: [NameTemplate.Field]
    /// The template it starts from, until the user changes it.
    public let defaultTemplate: String
    /// The ids of the modules it replaces, which the app then does not offer (ADR 0067).
    public let replaces: Set<String>
    /// Whether it reads the names in the same folder a year before, which Treewise gives it
    /// only while the user allows it (ADR 0090).
    public let readsYearBefore: Bool

    /// Creates what an add-on for names needs and offers.
    public init(
        contentTypes: Set<String>, neededContent: Set<ModuleContentKind>,
        fields: [NameTemplate.Field], defaultTemplate: String, replaces: Set<String> = [],
        readsYearBefore: Bool = false
    ) {
        self.contentTypes = contentTypes
        self.neededContent = neededContent
        self.fields = fields
        self.defaultTemplate = defaultTemplate
        self.replaces = replaces
        self.readsYearBefore = readsYearBefore
    }
}
