import Foundation
import TreewiseCore

/// What of a proposed name the review colours for the user to look at (ADR 0058): its gap,
/// else the date that came from the file.
public enum NameReviewLook {
    /// Why a stretch is coloured.
    public enum Kind: Hashable, Sendable {
        /// A gap for the user to fill in.
        case gap
        /// A date that comes from the file, to be checked.
        case dateToCheck
    }

    /// A date as names write one: with dots or dashes, or eight digits.
    private static let datePattern = "[0-9]{2,4}[.-][0-9]{2}[.-][0-9]{2,4}|[0-9]{8}"

    /// The stretch to colour, or nil when a name has no gap and no date from the file.
    public static func mark(in name: String, dateFromFile: Bool)
        -> (range: Range<String.Index>, kind: Kind)?
    {
        if let gap = name.range(of: NameTemplate.gap) { return (gap, .gap) }
        guard dateFromFile,
            let date = name.range(of: datePattern, options: .regularExpression)
        else { return nil }
        return (date, .dateToCheck)
    }
}
