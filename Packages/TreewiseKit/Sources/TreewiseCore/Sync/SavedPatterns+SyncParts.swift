import Foundation

/// The saved patterns as parts (ADR 0144): each pattern an element with its name, its text
/// together with its version, and its place in the list; the default a part of the list.
extension SavedPatterns {
    private enum Part {
        static let name = "name"
        static let text = "text"
        static let place = "place"
        static let defaultPattern = "default"
    }

    private struct Text: Codable {
        var text: String
        var version: Int
    }

    /// The list as elements and their parts.
    public var syncElements: [SyncElement: [String: JSONValue]] {
        var elements: [SyncElement: [String: JSONValue]] = [
            .patternList: [Part.defaultPattern: .string(defaultPattern.id)]
        ]
        for (index, pattern) in patterns.enumerated() {
            var parts: [String: JSONValue] = [
                Part.name: .string(pattern.name), Part.place: .number(Double(index)),
            ]
            parts[Part.text] = try? JSONValue(
                encoding: Text(text: pattern.text, version: pattern.version))
            elements[.pattern(pattern.id)] = parts
        }
        return elements
    }

    /// The list from the elements that are there: the patterns in the order of their
    /// places, then of their ids; the default the one named, or the first; the examples
    /// in `locale` when no pattern is left.
    public init(
        syncElements elements: [SyncElement: [String: JSONValue]], locale: Locale = .current
    ) {
        let patterns = elements.compactMap { element, parts -> (Double, SavedPattern)? in
            guard case .pattern(let id) = element,
                case .string(let name)? = parts[Part.name],
                let text = parts[Part.text]?.decoded(as: Text.self)
            else { return nil }
            let place: Double = if case .number(let value)? = parts[Part.place] { value } else { 0 }
            return (place, SavedPattern(id: id, name: name, text: text.text, version: text.version))
        }
        .sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1.id < $1.1.id }
        .map(\.1)
        guard let first = patterns.first else {
            self = .examples(locale: locale)
            return
        }
        let named: String? =
            if case .string(let id)? = elements[.patternList]?[Part.defaultPattern] { id } else {
                nil
            }
        let defaultID = named.flatMap { id in patterns.contains { $0.id == id } ? id : nil }
        self.init(patterns: patterns, defaultID: defaultID ?? first.id)
    }
}
