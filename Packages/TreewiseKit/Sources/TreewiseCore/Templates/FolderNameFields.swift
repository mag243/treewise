import Foundation

/// A folder's name in a template, read for its fields (ADR 0096): `{year}`, `{text}`, `{seq}`
/// and `{date}` with the formats of name patterns, and the repeats `{month}`, `{quarter}`
/// and `{half}` (ADR 0100). Anything else is plain text, `[ ]`, `< >`,
/// `|` and braces that hold no such field included, so a folder named `Archive [old]` or
/// `{draft}` stays as it is.
struct FolderNameFields {
    /// One piece of the name.
    enum Piece {
        case text(String)
        /// A field with its format, and the field as written, for a field left unfilled.
        case field(FolderTemplateField, NameTemplate.FieldFormat?, written: String)
        /// `{seq}` with its series.
        case number(NameTemplate.Series, written: String)
        /// A repeat with a month's format, nil for `MM`.
        case repeating(FolderRepeat, DateTemplate?, written: String)
    }

    /// What a year in two digits is the rest of.
    private static let century = 100
    /// What stands for a field in `plainText`, a character any folder's name can hold.
    private static let fieldStandIn = "x"
    /// A template's field, its name and what follows its colon.
    private static let expression: NSRegularExpression = {
        // swiftlint:disable:next force_try - a fixed expression, tested by every read
        try! NSRegularExpression(
            pattern: "\\{(year|text|seq|date|month|quarter|half)(?::([^{}]*))?\\}")
    }()

    let pieces: [Piece]

    /// Reads `name`, throwing `invalidFormat(name)` for a field with a format it does not take.
    init(_ name: String) throws(FolderTree.Problem) {
        var pieces: [Piece] = []
        var rest = name.startIndex
        let range = NSRange(name.startIndex..., in: name)
        for match in Self.expression.matches(in: name, range: range) {
            guard let whole = Range(match.range, in: name),
                let kind = Range(match.range(at: 1), in: name)
            else { continue }
            if rest < whole.lowerBound {
                pieces.append(.text(String(name[rest..<whole.lowerBound])))
            }
            let format = Range(match.range(at: 2), in: name).map { String(name[$0]) }
            guard let piece = Self.piece(String(name[kind]), format, written: String(name[whole]))
            else { throw .invalidFormat(name) }
            pieces.append(piece)
            rest = whole.upperBound
        }
        if rest < name.endIndex { pieces.append(.text(String(name[rest...]))) }
        self.pieces = pieces
    }

    private static func piece(_ kind: String, _ format: String?, written: String) -> Piece? {
        let field: FolderTemplateField
        let patternKind: NameTemplate.Field.Kind
        if let repeating = FolderRepeat(rawValue: kind) {
            return Self.repeatPiece(repeating, format, written: written)
        }
        switch kind {
        case "seq":
            guard let format else { return .number(.counting, written: written) }
            return NameTemplate.Series(format).map { .number($0, written: written) }
        case "year": (field, patternKind) = (.year, .year)
        case "text": (field, patternKind) = (.text, .text)
        default: (field, patternKind) = (.date, .date)
        }
        guard let format else { return .field(field, nil, written: written) }
        return NameTemplate.FieldFormat(format, for: patternKind).map {
            .field(field, $0, written: written)
        }
    }

    /// A repeat's piece: `{month}` takes a format that writes only the month, `{quarter}` and
    /// `{half}` none.
    private static func repeatPiece(_ repeating: FolderRepeat, _ format: String?, written: String)
        -> Piece?
    {
        guard let format else { return .repeating(repeating, nil, written: written) }
        guard repeating == .month, let template = DateTemplate(format), template.writesOnlyTheMonth
        else { return nil }
        return .repeating(repeating, template, written: written)
    }

    /// The repeats in the name, in order.
    var repeats: [FolderRepeat] {
        pieces.compactMap { piece in
            if case .repeating(let repeating, _, _) = piece { repeating } else { nil }
        }
    }

    /// The fields, each once, in the order they first appear.
    var fields: [FolderTemplateField] {
        var found: [FolderTemplateField] = []
        for piece in pieces {
            let field: FolderTemplateField
            switch piece {
            case .text, .repeating: continue
            case .field(let kind, _, _): field = kind
            case .number: field = .number
            }
            if !found.contains(field) { found.append(field) }
        }
        return found
    }

    /// The name with each field standing in as one plain character, to check the rest as a
    /// folder's name.
    var plainText: String {
        pieces.map { piece in
            if case .text(let text) = piece { text } else { Self.fieldStandIn }
        }.joined()
    }

    /// The name with the fields that have a value written in, and its repeat as the
    /// `occurrence`th month, quarter or half, counted from 1; without one it stays as written.
    func filled(with values: FolderTemplateValues, occurrence: Int? = nil) -> String {
        pieces.map { piece in
            switch piece {
            case .text(let text): text
            case .number(_, let written): values.number?.written ?? written
            case .field(let field, let format, let written):
                Self.write(field, format, values) ?? written
            case .repeating(let repeating, let format, let written):
                occurrence.map { Self.write(repeating, $0, format, values) } ?? written
            }
        }.joined()
    }

    private static func write(
        _ repeating: FolderRepeat, _ occurrence: Int, _ format: DateTemplate?,
        _ values: FolderTemplateValues
    ) -> String {
        guard repeating == .month else { return String(occurrence) }
        guard let format else { return String(format: "%02d", occurrence) }
        return format.write(
            year: values.year ?? 0, month: occurrence, day: 1, language: values.language)
    }

    /// A field written with its value in its format, or nil without a value. `{seq}` is
    /// written from its piece.
    static func write(
        _ field: FolderTemplateField, _ format: NameTemplate.FieldFormat?,
        _ values: FolderTemplateValues
    ) -> String? {
        switch field {
        case .year:
            guard let year = values.year else { return nil }
            return format == .twoDigitYear
                ? String(format: "%02d", year % Self.century) : String(year)
        case .text:
            guard let text = values.text?.trimmingCharacters(in: .whitespaces) else { return nil }
            guard case .textCase(let textCase) = format else { return text }
            return textCase.apply(to: text, locale: Locale(identifier: values.language.rawValue))
        case .date:
            guard let day = values.date else { return nil }
            return (format?.dateTemplate ?? .standard).write(
                year: day.year, month: day.month, day: day.day, language: values.language)
        case .number:
            return nil
        }
    }
}
