import Foundation
import TreewiseCore

/// A part of a proposed name a field filled in, with the colour of its field.
public struct NameFieldMark: Hashable, Sendable {
    /// Where it sits in the name.
    public let range: Range<String.Index>
    /// Its field's place among the fields of the pattern, which picks the colour the
    /// pattern shows it in too.
    public let colorIndex: Int
}

/// One proposed name for an item, as the menu of proposals while renaming shows it
/// (ADR 0066).
public struct NameOption: Hashable, Sendable {
    /// The name, with the item's extension.
    public let name: String
    /// What the fields of the pattern filled in, in their colours.
    public let marks: [NameFieldMark]
    /// The personal data in the name (ADR 0060).
    public let personalData: [PersonalData]
    /// Whether a required field is still a gap.
    public let hasGap: Bool
}

extension NameReviewModel {
    /// The parts of an item's proposed name that fields of the pattern filled in, to mark
    /// them while it is edited: what a module or the series filled in, not fixed text or the
    /// folder's name. A name the user typed has none.
    public func fieldMarks(of id: FileItem.ID) -> [NameFieldMark] {
        guard let entry = session?.entry(id), let name = entry.currentName,
            let index = entry.position?.index, index < entry.proposals.count
        else { return [] }
        return marks(in: name, from: entry.proposals[index].moduleIDs.first)
    }

    /// An item's proposed names, in the order of its options.
    public func options(of id: FileItem.ID) -> [NameOption] {
        (session?.entry(id)?.proposals ?? []).map { proposal in
            NameOption(
                name: proposal.name,
                marks: marks(in: proposal.name, from: proposal.moduleIDs.first),
                personalData: PersonalData.found(in: ProposedName.stem(of: proposal.name)),
                hasGap: proposal.name.contains(NameTemplate.gap))
        }
    }

    private func marks(in name: String, from moduleID: String?) -> [NameFieldMark] {
        guard let template = modules.first(where: { $0.id == moduleID })?.template else {
            return []
        }
        // The extension comes after the stem, so ranges in the stem hold in the name.
        let order = NameTemplate.fieldOrder(in: template.text)
        return template.fieldMarks(
            in: ProposedName.stem(of: name), fixed: folderValues
        ).map { NameFieldMark(range: $0.range, colorIndex: order.firstIndex(of: $0.key) ?? 0) }
    }
}
