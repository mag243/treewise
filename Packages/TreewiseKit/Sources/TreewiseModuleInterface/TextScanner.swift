import Foundation
import TreewiseCore

/// Finds what is general in a document's text, for modules to build on: dates and
/// amounts. What they mean in a document is for a module to decide (ADR 0057).
public enum TextScanner {
    private static let months: [String: Int] = [
        "jan": 1, "januari": 1, "january": 1, "januar": 1,
        "feb": 2, "februari": 2, "february": 2, "februar": 2,
        "mar": 3, "mrt": 3, "mär": 3, "maart": 3, "march": 3, "märz": 3,
        "apr": 4, "april": 4,
        "mei": 5, "may": 5, "mai": 5,
        "jun": 6, "juni": 6, "june": 6,
        "jul": 7, "juli": 7, "july": 7,
        "aug": 8, "augustus": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "okt": 10, "oct": 10, "oktober": 10, "october": 10,
        "nov": 11, "november": 11,
        "dec": 12, "dez": 12, "december": 12, "dezember": 12,
    ]
    private static let currency = "€|EUR|\\$|USD|£|GBP"
    private static let dayMonthYear = #"\b(\d{1,2})[-./](\d{1,2})[-./](\d{4})\b"#
    private static let yearMonthDay = #"\b(\d{4})[-.](\d{2})[-.](\d{2})\b"#
    private static let namedMonth = #"\b(\d{1,2})\.?\s+(\p{L}+)\.?\s+(\d{4})\b"#
    /// Decimals of an amount as written: one or two digits after the last separator.
    private static let maximumDecimals = 2

    /// The dates in a text, in their order. A date that does not exist is left out.
    public static func dates(in text: String) -> [NameTemplate.Value] {
        let dayFirst = matches(of: dayMonthYear, in: text).compactMap { match in
            located(match) { date(year: Int($0[2]), month: Int($0[1]), day: Int($0[0])) }
        }
        let yearFirst = matches(of: yearMonthDay, in: text).compactMap { match in
            located(match) { date(year: Int($0[0]), month: Int($0[1]), day: Int($0[2])) }
        }
        let named = matches(of: namedMonth, in: text).compactMap { match in
            located(match) {
                date(year: Int($0[2]), month: months[$0[1].lowercased()], day: Int($0[0]))
            }
        }
        return (dayFirst + yearFirst + named).sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// The amounts with a currency in a text, in their order, written like `1234.56`.
    public static func amounts(in text: String) -> [String] {
        let number = #"(\d[\d.,]*)"#
        let found =
            matches(of: "(?:\(currency))\\s*" + number, in: text)
            + matches(of: number + "\\s*(?:\(currency))", in: text)
        return found.sorted { $0.0 < $1.0 }.compactMap { normalized($0.1[0]) }
    }

    private static func located(
        _ match: (Int, [String]), _ read: ([String]) -> NameTemplate.Value?
    ) -> (Int, NameTemplate.Value)? {
        read(match.1).map { (match.0, $0) }
    }

    private static func date(year: Int?, month: Int?, day: Int?) -> NameTemplate.Value? {
        guard let year, let month, let day else { return nil }
        let components = DateComponents(
            calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day)
        return components.isValidDate ? .date(year: year, month: month, day: day) : nil
    }

    /// Reads `1.234,56` and `1,234.56` alike: only a last separator with at most two
    /// digits after it is a decimal one.
    private static func normalized(_ written: String) -> String? {
        let trimmed = written.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        var whole = trimmed
        var decimals = ""
        if let separator = trimmed.lastIndex(where: { $0 == "." || $0 == "," }) {
            let after = trimmed[trimmed.index(after: separator)...]
            if after.count <= maximumDecimals {
                whole = String(trimmed[..<separator])
                decimals = String(after)
            }
        }
        let digits = whole.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        let padding = String(repeating: "0", count: maximumDecimals - decimals.count)
        return digits + "." + decimals + padding
    }

    private static func matches(of pattern: String, in text: String) -> [(Int, [String])] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: whole).map { match in
            let groups = (1..<match.numberOfRanges).compactMap { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
            return (match.range.location, groups)
        }
    }
}
