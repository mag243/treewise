import Foundation

/// A pattern the user keeps under a name of their own (ADR 0068).
public struct SavedPattern: Hashable, Sendable, Codable, Identifiable {
    /// A stable id, which means nothing outside the list.
    public let id: String
    /// The name the user gave it.
    public var name: String
    /// The text of the pattern, without spaces at its ends.
    public var text: String

    /// Creates a saved pattern.
    public init(id: String, name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}

/// The user's list of named patterns, one of them the default that a folder without a
/// pattern of its own is offered (ADR 0068). The list is the app's, not a module's.
///
/// Invariant: the list is never empty, and the default is one of its patterns.
public struct SavedPatterns: Hashable, Sendable, Codable {
    /// Why a change to the list is not made.
    public enum Problem: Error, Hashable, Sendable {
        /// A pattern needs a name to be found by.
        case emptyName
        /// The last pattern stays, as one has to be the default.
        case lastPattern
    }

    /// The patterns, in the user's order.
    public private(set) var patterns: [SavedPattern]
    private var defaultID: SavedPattern.ID

    /// The pattern a folder without one of its own is offered.
    public var defaultPattern: SavedPattern {
        patterns.first { $0.id == defaultID } ?? patterns[0]
    }

    private init(patterns: [SavedPattern], defaultID: SavedPattern.ID) {
        precondition(!patterns.isEmpty, "the list is never empty")
        self.patterns = patterns
        self.defaultID = defaultID
    }

    private enum CodingKeys: String, CodingKey {
        case patterns, defaultID
    }

    /// Reads a stored list; one without patterns is not a list.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let patterns = try container.decode([SavedPattern].self, forKey: .patterns)
        guard let first = patterns.first else {
            throw DecodingError.dataCorruptedError(
                forKey: .patterns, in: container, debugDescription: "A list is never empty")
        }
        let defaultID = try container.decode(SavedPattern.ID.self, forKey: .defaultID)
        self.init(
            patterns: patterns,
            defaultID: patterns.contains { $0.id == defaultID } ? defaultID : first.id)
    }

    /// The list a user starts with: a few general patterns, the first the default.
    public static func examples(locale: Locale = .current) -> SavedPatterns {
        let bundle = Bundle.module.localizationBundle(for: locale)
        func named(_ name: String.LocalizationValue, _ text: String) -> SavedPattern {
            SavedPattern(
                id: UUID().uuidString,
                name: String(localized: name, bundle: bundle, locale: locale), text: text)
        }
        let patterns = [
            named("Date and Text", "{date:yyyy.MM.dd} {text}"),
            named("Date with Dashes and Text", "{date:yyyy-MM-dd} {text}"),
            named("Folder and Number", "{folder} {seq}"),
            named("Date, Folder and Text", "{date:yyyy.MM.dd} {folder} - {text}"),
        ]
        return SavedPatterns(patterns: patterns, defaultID: patterns[0].id)
    }

    /// The examples, with a default pattern kept from before the list as its default:
    /// the example with the same text, or a pattern of its own.
    public init(keeping defaultText: String, locale: Locale = .current) {
        var list = Self.examples(locale: locale)
        let text = Self.trimmed(defaultText)
        if let example = list.patterns.first(where: { $0.text == text }) {
            list.defaultID = example.id
        } else if !text.isEmpty {
            let bundle = Bundle.module.localizationBundle(for: locale)
            let own = SavedPattern(
                id: UUID().uuidString,
                name: String(localized: "My Pattern", bundle: bundle, locale: locale), text: text)
            list.patterns.append(own)
            list.defaultID = own.id
        }
        self = list
    }

    /// Adds a pattern at the end, and returns its id.
    public mutating func save(name: String, text: String) -> Result<SavedPattern.ID, Problem> {
        let name = Self.trimmed(name)
        guard !name.isEmpty else { return .failure(.emptyName) }
        let pattern = SavedPattern(id: UUID().uuidString, name: name, text: Self.trimmed(text))
        patterns.append(pattern)
        return .success(pattern.id)
    }

    /// Gives a pattern another name; returns why not, or nil when it did.
    @discardableResult
    public mutating func rename(_ id: SavedPattern.ID, to name: String) -> Problem? {
        let name = Self.trimmed(name)
        guard !name.isEmpty else { return .emptyName }
        if let index = patterns.firstIndex(where: { $0.id == id }) { patterns[index].name = name }
        return nil
    }

    /// Changes the text of a pattern. Folders that use it unchanged follow it (ADR 0068).
    public mutating func change(_ id: SavedPattern.ID, to text: String) {
        if let index = patterns.firstIndex(where: { $0.id == id }) {
            patterns[index].text = Self.trimmed(text)
        }
    }

    /// Removes a pattern; the first becomes the default when it was. The last one stays.
    /// Returns why not, or nil when it did.
    @discardableResult
    public mutating func remove(_ id: SavedPattern.ID) -> Problem? {
        guard patterns.count > 1 else { return .lastPattern }
        patterns.removeAll { $0.id == id }
        if !patterns.contains(where: { $0.id == defaultID }) { defaultID = patterns[0].id }
        return nil
    }

    /// Makes a pattern of the list the default.
    public mutating func makeDefault(_ id: SavedPattern.ID) {
        if patterns.contains(where: { $0.id == id }) { defaultID = id }
    }

    /// Moves patterns, as a list that is dragged in order does.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { patterns[$0] }
        let before = source.filter { $0 < destination }.count
        for index in source.sorted(by: >) { patterns.remove(at: index) }
        patterns.insert(contentsOf: moving, at: destination - before)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }
}
