import Foundation

/// A field an add-on recognizes, written as in a pattern, with its kind and an example of
/// what it writes, for Settings' Add-ons tab (ADR 0088, ADR 0092).
public struct RecognizedField: Equatable, Sendable {
    /// What kind of thing the field stands for.
    public enum Kind: Equatable, Sendable {
        case date, series, text, choice
    }

    /// The field as the add-on writes it, as `{seq:4}` or `<…|…>`.
    public let token: String
    public let kind: Kind
    /// What the field writes, as `1–4` for `{seq:4}`; empty when there is no example.
    public let example: String

    private static let seriesPrefix = "{seq"
    /// How many numbers a series without an end shows before `…`.
    private static let openSeriesShown = 3

    /// The field `token`, with dates as of `today` in `calendar` and words in `locale`.
    public init(_ token: String, today: Date, calendar: Calendar, locale: Locale = .current) {
        self.token = token
        let bundle = Bundle.module.localizationBundle(for: locale)
        let day = calendar.dateComponents([.year, .month, .day], from: today)
        let year = day.year ?? 0
        if token.hasPrefix("<") {
            kind = .choice
            example = String(localized: "one of several", bundle: bundle, locale: locale)
        } else if token.hasPrefix("{date") {
            kind = .date
            let format = Self.argument(of: token).flatMap(DateTemplate.init) ?? .standard
            example = format.write(year: year, month: day.month ?? 1, day: day.day ?? 1)
        } else if token.hasPrefix("{year") {
            kind = .date
            example = String(year)
        } else if token.hasPrefix(Self.seriesPrefix) {
            kind = .series
            example = Self.series(token).map(Self.example) ?? ""
        } else {
            kind = .text
            example =
                switch token {
                case "{text}": String(localized: "words", bundle: bundle, locale: locale)
                case "{folder}": String(localized: "Tax", bundle: bundle, locale: locale)
                default: ""
                }
        }
    }

    /// What follows the field's first colon, without the closing brace; nil without one.
    private static func argument(of token: String) -> String? {
        guard let colon = token.firstIndex(of: ":"), token.hasSuffix("}") else { return nil }
        return String(token[token.index(after: colon)..<token.index(before: token.endIndex)])
    }

    private static func series(_ token: String) -> NameTemplate.Series? {
        if token == seriesPrefix + "}" { return .counting }
        return argument(of: token).flatMap(NameTemplate.Series.init)
    }

    private static func example(of series: NameTemplate.Series) -> String {
        let width = series.width
        func written(_ number: Int) -> String {
            let digits = String(number)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
        switch series.numbers {
        case .list(let list):
            return list.map(written).joined(separator: " ")
        case .range(let first, let last?):
            return written(first) + "–" + written(last)
        case .range(let first, nil):
            let shown = (first..<first + openSeriesShown).map(written)
            return shown.joined(separator: ", ") + " …"
        }
    }
}
