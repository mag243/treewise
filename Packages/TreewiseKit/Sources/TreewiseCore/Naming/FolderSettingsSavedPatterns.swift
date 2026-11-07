/// The saved pattern a folder's template for a module was picked from (ADR 0068).
public struct SavedPatternLink: Hashable, Sendable, Codable {
    /// The saved pattern's id.
    public var id: String
    /// Whether the folder's template differs from the saved pattern, so it follows it no
    /// more.
    public var isChanged: Bool

    /// Creates a link.
    public init(id: String, isChanged: Bool) {
        self.id = id
        self.isChanged = isChanged
    }
}

/// A folder follows the saved pattern it uses unchanged, and keeps a copy of its text
/// (ADR 0068).
extension FolderSettings {
    /// Gives a module a saved pattern's text, and follows that pattern.
    public mutating func use(savedPattern id: String, text: String, for module: String) {
        templates[module] = text
        savedPatternLinks[module] = SavedPatternLink(id: id, isChanged: false)
    }

    /// Takes a template the user wrote; the folder follows its saved pattern only while the
    /// text is the saved one, `savedText`, nil when that pattern is gone.
    public mutating func changeTemplate(_ text: String, for module: String, savedText: String?) {
        templates[module] = text
        guard savedPatternLinks[module] != nil else { return }
        guard let savedText else {
            savedPatternLinks[module] = nil
            return
        }
        savedPatternLinks[module]?.isChanged = text != savedText
    }

    /// Ends the link of a module's template to a saved pattern; the text stays.
    public mutating func unlinkSavedPattern(for module: String) {
        savedPatternLinks[module] = nil
    }

    /// Gives each module that uses a saved pattern unchanged that pattern's text now.
    /// A pattern that is gone, or that `usable` says the module cannot use, ends the link,
    /// and the module keeps its copy.
    ///
    /// - Parameters:
    ///   - savedPatterns: The text of each saved pattern, by id.
    ///   - usable: Whether a module, by id, can use a text.
    public mutating func follow(
        savedPatterns: [String: String], usable: (String, String) -> Bool
    ) {
        for (module, link) in savedPatternLinks where !link.isChanged {
            if let text = savedPatterns[link.id], usable(module, text) {
                templates[module] = text
            } else {
                savedPatternLinks[module] = nil
            }
        }
    }
}
