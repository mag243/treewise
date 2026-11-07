/// The saved pattern a folder's template for a module was picked from (ADR 0068).
public struct SavedPatternLink: Hashable, Sendable, Codable {
    /// The saved pattern's id.
    public var id: String
    /// The version of the saved pattern the folder uses.
    public var version: Int
    /// Whether the folder's template differs from the saved pattern, so it is offered no
    /// newer version.
    public var isChanged: Bool
    /// A newer version the user chose not to take, which is not offered again.
    public var skippedVersion: Int?

    /// Creates a link.
    public init(id: String, version: Int, isChanged: Bool = false, skippedVersion: Int? = nil) {
        self.id = id
        self.version = version
        self.isChanged = isChanged
        self.skippedVersion = skippedVersion
    }
}

/// A folder keeps the saved pattern it uses as it was, and is offered a newer version
/// (ADR 0068). It never changes its template by itself.
extension FolderSettings {
    /// Gives a module a saved pattern, at its version now.
    public mutating func use(_ pattern: SavedPattern, for module: String) {
        templates[module] = pattern.text
        savedPatternLinks[module] = SavedPatternLink(id: pattern.id, version: pattern.version)
    }

    /// Takes a template the user wrote. The folder counts as unchanged only while the text
    /// is the saved pattern's, `savedText`; nil when that pattern is gone ends the link.
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

    /// The newer version of the saved pattern a module uses unchanged, to offer; nil when
    /// there is none, the folder changed its pattern, or the user skipped that version.
    public func newerVersion(for module: String, in patterns: [SavedPattern]) -> SavedPattern? {
        guard let link = savedPatternLinks[module], !link.isChanged,
            let pattern = patterns.first(where: { $0.id == link.id }),
            pattern.version > link.version, pattern.version != link.skippedVersion
        else { return nil }
        return pattern
    }

    /// Keeps the module's template and does not offer this version again; the next is.
    public mutating func skip(version: Int, for module: String) {
        savedPatternLinks[module]?.skippedVersion = version
    }

    /// Ends the links to saved patterns that are gone, or that `usable` says the module
    /// cannot use any more; each module keeps its copy of the text.
    ///
    /// - Parameters:
    ///   - patterns: The saved patterns now.
    ///   - usable: Whether a module, by id, can use a text.
    public mutating func dropLinks(
        notIn patterns: [SavedPattern], usable: (String, String) -> Bool
    ) {
        for (module, link) in savedPatternLinks {
            guard let pattern = patterns.first(where: { $0.id == link.id }),
                usable(module, pattern.text)
            else {
                savedPatternLinks[module] = nil
                continue
            }
        }
    }
}
