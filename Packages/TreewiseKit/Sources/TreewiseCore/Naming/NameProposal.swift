/// A name made for an item from a module's values (ADR 0057). The values come from
/// a module and are not trusted: `ProposedName` checks the name before it can reach
/// a file.
public struct NameProposal: Hashable, Sendable {
    /// Where a date in the name comes from, when it comes from the file and not from a
    /// document's contents. Such a date is a suggestion for the user to look at.
    public enum DateSource: String, Hashable, Sendable, Codable {
        /// Inside the file: a PDF's creation date or a photo's capture date.
        case insideFile
        /// The file system's dates of the file.
        case fileSystem
    }

    /// The name, with or without the item's extension.
    public let name: String
    /// The module whose values made it.
    public let moduleID: String
    /// Where its date comes from, or nil when it has no such date.
    public let dateSource: DateSource?

    /// Creates a proposal.
    public init(name: String, moduleID: String, dateSource: DateSource? = nil) {
        self.name = name
        self.moduleID = moduleID
        self.dateSource = dateSource
    }

    /// Makes the proposals for a module's ranked sets of values, in their order. A set
    /// without any value gives none. Treewise supplies the folder's name itself, so a
    /// module never sees it. A date equal to `suggestedDate` keeps that date's source.
    public static func make(
        from valueSets: [[String: NameTemplate.Value]], template: NameTemplate, moduleID: String,
        folderName: String, suggestedDate: SuggestedDate?
    ) -> [NameProposal] {
        valueSets.compactMap { values in
            var all = values
            all[NameTemplate.Field.folder.name] = .text(folderName)
            let source = suggestedDate.flatMap { date in
                template.uses(date: date.value, in: all) ? date.source : nil
            }
            return template.name(from: all).map {
                NameProposal(name: $0, moduleID: moduleID, dateSource: source)
            }
        }
    }
}
