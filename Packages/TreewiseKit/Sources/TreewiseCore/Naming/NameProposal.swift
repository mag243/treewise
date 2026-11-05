/// A name made for an item from a module's values (ADR 0057). The values come from
/// a module and are not trusted: `ProposedName` checks the name before it can reach
/// a file.
public struct NameProposal: Hashable, Sendable {
    /// The name, with or without the item's extension.
    public let name: String
    /// The module whose values made it.
    public let moduleID: String

    /// Creates a proposal.
    public init(name: String, moduleID: String) {
        self.name = name
        self.moduleID = moduleID
    }

    /// Makes the proposals for a module's ranked sets of values, in their order. A set
    /// that leaves a required field empty gives none. Treewise supplies the folder's
    /// name itself, so a module never sees it.
    public static func make(
        from valueSets: [[String: NameTemplate.Value]], template: NameTemplate, moduleID: String,
        folderName: String
    ) -> [NameProposal] {
        valueSets.compactMap { values in
            var all = values
            all[NameTemplate.Field.folder.name] = .text(folderName)
            return template.name(from: all).map { NameProposal(name: $0, moduleID: moduleID) }
        }
    }
}
