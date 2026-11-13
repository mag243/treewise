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

    /// The id of a proposal from Treewise itself, like repairing stray spaces.
    public static let treewiseID = "treewise"

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

    /// Makes the proposals for a module's ranked sets of values, in their order, each with
    /// a name per part of a choice of parts (ADR 0064). A set without any value gives none.
    /// Treewise supplies the folder's name and the next period itself, so a module never
    /// sees them. A date equal to `suggestedDate`, or a year taken from it, keeps that
    /// date's source.
    ///
    /// - Parameters:
    ///   - foldersAbove: The names of the folders above the item's folder, nearest first,
    ///     for `{folder:2}` and higher (ADR 0089).
    ///   - siblingNames: The names of the other items in the folder, for the series.
    ///   - currentName: The item's name, which puts the part it fits first. When it nearly
    ///     fits, it comes first itself, with the template's fixed text and the folder's name
    ///     written right.
    public static func make(
        from valueSets: [[String: NameTemplate.Value]], template: NameTemplate, moduleID: String,
        folderName: String, foldersAbove: [String] = [], suggestedDate: SuggestedDate?,
        siblingNames: [String] = [], currentName: String = ""
    ) -> [NameProposal] {
        let folders = NameTemplate.folderValues([folderName] + foldersAbove)
        let context = NameTemplate.Context(
            siblingNames: siblingNames.map(ProposedName.stem(of:)),
            currentName: ProposedName.stem(of: currentName), fileYear: suggestedDate?.year)
        // A name that nearly fits comes first, written right (ADR 0067).
        let corrected = template.correctedName(context.currentName, fixed: folders)
            .map { NameProposal(name: $0, moduleID: moduleID) }
        let made = valueSets.flatMap { values in
            // Treewise names the folders; a module cannot.
            var all = values
            for (key, name) in folders { all[key] = .text(name) }
            let usesDate = suggestedDate.map { template.uses(date: $0.value, in: all) } ?? false
            return template.names(from: all, context: context).map { made in
                NameProposal(
                    name: made.name, moduleID: moduleID,
                    dateSource: usesDate || made.usesFileYear ? suggestedDate?.source : nil)
            }
        }
        guard let corrected else { return made }
        return [corrected] + made.filter { $0.name != corrected.name }
    }
}
