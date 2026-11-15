import Foundation

/// The format of a date field, made of `yyyy`, `yy`, `MM`, `MMMM` (the month's name),
/// `MMM` (its short name), `dd`, `d` (the day without a leading zero) and separators, with
/// `@en`, `@nl` or `@de` at the end for the language of a month's name (ADR 0067).
struct DateTemplate: Hashable, Sendable {
    private enum Piece: Hashable, Sendable {
        case longYear
        case shortYear
        case month
        case monthName(short: Bool)
        case day
        case shortDay
        case separator(Character)
    }

    /// The format of a date field that names none.
    static let standard = DateTemplate(pieces: [
        .longYear, .separator("-"), .month, .separator("-"), .day,
    ])

    private static let separators: Set<Character> = [".", "-", "_", " "]
    /// The tokens, the longest of each letter first, so `MMMM` is not read as `MM` twice.
    private static let tokens: [(String, Piece)] = [
        ("yyyy", .longYear), ("yy", .shortYear), ("MMMM", .monthName(short: false)),
        ("MMM", .monthName(short: true)), ("MM", .month), ("dd", .day), ("d", .shortDay),
    ]
    private static let languageMark: Character = "@"

    private let pieces: [Piece]
    /// The language of a month's name; nil for the app's language.
    private let language: MonthNames.Language?

    private init(pieces: [Piece]) {
        self.pieces = pieces
        self.language = nil
    }

    /// Reads a format; nil when it holds anything else than tokens and separators, or
    /// names a language Treewise does not speak.
    init?(_ text: String) {
        var format = Substring(text)
        var language: MonthNames.Language?
        if let mark = text.lastIndex(of: Self.languageMark) {
            guard
                let named = MonthNames.Language(rawValue: String(text[text.index(after: mark)...]))
            else { return nil }
            language = named
            format = text[..<mark]
        }
        self.language = language
        var rest = format
        var pieces: [Piece] = []
        while let first = rest.first {
            if let (token, piece) = Self.tokens.first(where: { rest.hasPrefix($0.0) }) {
                pieces.append(piece)
                rest = rest.dropFirst(token.count)
            } else if Self.separators.contains(first) {
                pieces.append(.separator(first))
                rest = rest.dropFirst()
            } else {
                return nil
            }
        }
        guard pieces.contains(where: { if case .separator = $0 { false } else { true } }) else {
            return nil
        }
        self.pieces = pieces
    }

    /// Whether it writes the month only, by its number or its name, as a repeating folder's
    /// `{month}` does (ADR 0100).
    var writesOnlyTheMonth: Bool {
        pieces.allSatisfy { piece in
            switch piece {
            case .month, .monthName, .separator: true
            default: false
            }
        }
    }

    /// Writes a date in this format, a month's name in the format's language, else in
    /// `language`.
    func write(
        year: Int, month: Int, day: Int, language fallback: MonthNames.Language = .app
    ) -> String {
        pieces.map { piece in
            switch piece {
            case .longYear: String(format: "%04d", year)
            case .shortYear: TwoDigitYear.write(year)
            case .month: String(format: "%02d", month)
            case .monthName(let short):
                MonthNames.name(of: month, short: short, in: language ?? fallback)
            case .day: String(format: "%02d", day)
            case .shortDay: String(day)
            case .separator(let character): String(character)
            }
        }.joined()
    }

    /// A regular expression that recognizes a date in this format.
    var pattern: String {
        pieces.map { piece in
            switch piece {
            case .longYear: "[0-9]{4}"
            case .shortYear, .month, .day: "[0-9]{2}"
            case .shortDay: "[0-9]{1,2}"
            case .monthName: MonthNames.pattern
            case .separator(let character):
                NSRegularExpression.escapedPattern(for: String(character))
            }
        }.joined()
    }
}
