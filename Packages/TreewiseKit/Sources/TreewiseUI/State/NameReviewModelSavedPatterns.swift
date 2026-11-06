import TreewiseCore

/// A saved pattern as an add-on's menu offers it (ADR 0068).
public struct SavedPatternChoice: Identifiable, Hashable, Sendable {
    /// The pattern.
    public let pattern: SavedPattern
    /// Why this add-on cannot use it, such as a field it does not know, or nil.
    public let problem: NameTemplate.Problem?
    /// Whether it is the add-on's pattern in this folder now.
    public let isCurrent: Bool

    public var id: SavedPattern.ID { pattern.id }
}

/// Picking a saved pattern for an add-on, and saving an add-on's pattern (ADR 0068).
extension NameReviewModel {
    /// The saved patterns, in the user's order, each with whether this add-on can use it.
    public func savedPatternChoices(for moduleID: String) -> [SavedPatternChoice] {
        guard let module = modules.first(where: { $0.id == moduleID }) else { return [] }
        let fields = module.description.fields + NameTemplate.Field.suppliedByTreewise
        return dependencies.savedPatterns().patterns.map { pattern in
            var problem: NameTemplate.Problem?
            if case .failure(let found) = NameTemplate.parse(pattern.text, fields: fields) {
                problem = found
            }
            return SavedPatternChoice(
                pattern: pattern, problem: problem, isCurrent: module.templateText == pattern.text)
        }
    }

    /// Gives this folder a saved pattern for an add-on, as typing it would.
    public func useSavedPattern(_ id: SavedPattern.ID, for moduleID: String) async {
        guard let pattern = dependencies.savedPatterns().patterns.first(where: { $0.id == id })
        else { return }
        await setTemplate(moduleID, to: pattern.text)
    }

    /// Saves an add-on's pattern in this folder under a name; returns why not, or nil.
    public func savePattern(of moduleID: String, as name: String) -> SavedPatterns.Problem? {
        guard let module = modules.first(where: { $0.id == moduleID }) else { return nil }
        return dependencies.savePattern(name, module.templateText)
    }
}
