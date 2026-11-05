import Foundation

/// The format of a date field, made of `yyyy`, `yy`, `MM`, `dd` and separators.
struct DateTemplate: Hashable, Sendable {
    private enum Piece: Hashable, Sendable {
        case longYear
        case shortYear
        case month
        case day
        case separator(Character)
    }

    /// The format of a date field that names none.
    static let standard = DateTemplate(pieces: [
        .longYear, .separator("-"), .month, .separator("-"), .day,
    ])

    private static let separators: Set<Character> = [".", "-", "_", " "]
    private static let tokens: [(String, Piece)] = [
        ("yyyy", .longYear), ("yy", .shortYear), ("MM", .month), ("dd", .day),
    ]
    private static let shortYearDivisor = 100
    private static let shortYearBase = 2000

    private let pieces: [Piece]

    private init(pieces: [Piece]) {
        self.pieces = pieces
    }

    /// Reads a format; nil when it holds anything else than tokens and separators.
    init?(_ text: String) {
        var rest = Substring(text)
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

    /// Writes a date in this format.
    func write(year: Int, month: Int, day: Int) -> String {
        pieces.map { piece in
            switch piece {
            case .longYear: String(format: "%04d", year)
            case .shortYear: String(format: "%02d", year % Self.shortYearDivisor)
            case .month: String(format: "%02d", month)
            case .day: String(format: "%02d", day)
            case .separator(let character): String(character)
            }
        }.joined()
    }

    /// Reads a date written in this format; nil when the text is not.
    func read(_ text: String) -> NameTemplate.Value? {
        var rest = Substring(text)
        var year = 0
        var month = 0
        var day = 0
        for piece in pieces {
            switch piece {
            case .separator: rest = rest.dropFirst()
            case .longYear: year = Self.take(4, from: &rest)
            case .shortYear: year = Self.shortYearBase + Self.take(2, from: &rest)
            case .month: month = Self.take(2, from: &rest)
            case .day: day = Self.take(2, from: &rest)
            }
        }
        return .date(year: year, month: month, day: day)
    }

    private static func take(_ count: Int, from rest: inout Substring) -> Int {
        let digits = rest.prefix(count)
        rest = rest.dropFirst(count)
        return Int(digits) ?? 0
    }

    /// A regular expression that recognizes a date in this format.
    var pattern: String {
        pieces.map { piece in
            switch piece {
            case .longYear: "[0-9]{4}"
            case .shortYear, .month, .day: "[0-9]{2}"
            case .separator(let character):
                NSRegularExpression.escapedPattern(for: String(character))
            }
        }.joined()
    }
}
