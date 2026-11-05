/// A date Treewise read from a file, offered to modules with its source (ADR 0057).
public struct SuggestedDate: Hashable, Sendable, Codable {
    /// The year.
    public let year: Int
    /// The month, from 1.
    public let month: Int
    /// The day of the month.
    public let day: Int
    /// Where the date comes from.
    public let source: NameProposal.DateSource

    /// Creates a date.
    public init(year: Int, month: Int, day: Int, source: NameProposal.DateSource) {
        self.year = year
        self.month = month
        self.day = day
        self.source = source
    }

    /// The date as a value for a template.
    public var value: NameTemplate.Value {
        .date(year: year, month: month, day: day)
    }
}
