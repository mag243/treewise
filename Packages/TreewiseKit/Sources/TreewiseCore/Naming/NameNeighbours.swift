import Foundation

/// The names around a new name at its sorted place in a folder, so the user can judge
/// whether it fits the rest (ADR 0057).
public enum NameNeighbours {
    /// A name in the list.
    public struct Entry: Hashable, Sendable {
        /// The name.
        public let name: String
        /// Whether it is the new name.
        public let isNew: Bool

        /// Creates an entry.
        public init(name: String, isNew: Bool) {
            self.name = name
            self.isNew = isNew
        }
    }

    /// The new name with at most `reach` names on each side, sorted as a folder sorts them.
    public static func around(_ name: String, among others: [String], reach: Int) -> [Entry] {
        let sorted = (others + [name]).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        guard let place = sorted.firstIndex(of: name) else { return [] }
        let start = max(0, place - reach)
        let end = min(sorted.count - 1, place + reach)
        return (start...end).map { Entry(name: sorted[$0], isNew: $0 == place) }
    }
}
