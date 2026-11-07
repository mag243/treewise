import TreewiseCore
import TreewiseModuleInterface

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
        guard modules.first(where: { $0.id == moduleID })?.templateProblem == nil else { return }
        settings.use(savedPattern: id, text: pattern.text, for: moduleID)
        await saveSettings()
    }

    /// Takes a pattern found in the folder; the folder follows no saved pattern then.
    public func useFoundPattern(_ text: String, for moduleID: String) async {
        await setTemplate(moduleID, to: text)
        settings.unlinkSavedPattern(for: moduleID)
        await saveSettings()
    }

    /// The saved pattern the add-on's pattern here was picked from, when it has been changed
    /// since, for Update "name" (ADR 0068); nil otherwise.
    public func savedPatternToUpdate(for moduleID: String) -> SavedPattern? {
        guard settings.savedPatternLinks[moduleID]?.isChanged == true else { return nil }
        return linkedSavedPattern(of: moduleID)
    }

    /// Gives the saved pattern the add-on's pattern was picked from this folder's text, and
    /// the folder follows it again, as do the folders that use it unchanged.
    public func updateSavedPattern(for moduleID: String) async {
        guard let pattern = savedPatternToUpdate(for: moduleID),
            let text = modules.first(where: { $0.id == moduleID })?.templateText
        else { return }
        dependencies.changeSavedPattern(pattern.id, text)
        settings.savedPatternLinks[moduleID]?.isChanged = false
        await saveSettings()
    }

    /// The saved pattern a module's pattern here was picked from, if it still exists.
    func linkedSavedPattern(of moduleID: String) -> SavedPattern? {
        guard let link = settings.savedPatternLinks[moduleID] else { return nil }
        return dependencies.savedPatterns().patterns.first { $0.id == link.id }
    }

    /// Gives each module that uses a saved pattern unchanged that pattern as it is now.
    func followSavedPatterns(_ descriptions: [NameModuleDescription]) async {
        guard !settings.savedPatternLinks.isEmpty else { return }
        let before = settings
        let texts = Dictionary(
            dependencies.savedPatterns().patterns.map { ($0.id, $0.text) }
        ) { first, _ in first }
        settings.follow(savedPatterns: texts) { moduleID, text in
            descriptions.first { $0.id == moduleID }.map { Self.parse(text, for: $0) != nil }
                ?? false
        }
        if settings != before { await saveSettings() }
    }

    /// Saves an add-on's pattern in this folder under a name; returns why not, or nil.
    public func savePattern(of moduleID: String, as name: String) -> SavedPatterns.Problem? {
        guard let module = modules.first(where: { $0.id == moduleID }) else { return nil }
        return dependencies.savePattern(name, module.templateText)
    }
}
