import Foundation

/// A pattern for file names, written like `{date:yyyy.MM.dd} {company}[ - {number}]`:
/// fields, fixed text, and optional parts that fall away when a field is empty. It both
/// makes a name from values and recognizes one, so Treewise can judge whether a name
/// fits without running a module or reading a file (ADR 0057).
///
/// Invariant: every field is one the template was parsed with, and something outside
/// optional parts is required.
public struct NameTemplate: Hashable, Sendable {
    /// A field a module can fill in.
    public struct Field: Hashable, Sendable, Codable {
        /// What a field holds, which decides what it recognizes.
        public enum Kind: String, Hashable, Sendable, Codable {
            /// A date, written in the field's format.
            case date
            /// A word without spaces that holds a digit, like `F26009` or `26G0320014-1`.
            case number
            /// Any text.
            case text
            /// One exact value that Treewise supplies and no module sees, like a folder's name.
            case fixed
        }

        /// The name of the folder that holds the item, for every module's templates.
        public static let folder = Field(name: "folder", kind: .fixed)

        /// The name written between the braces.
        public let name: String
        /// What the field holds.
        public let kind: Kind

        /// Creates a field.
        public init(name: String, kind: Kind) {
            self.name = name
            self.kind = kind
        }
    }

    /// A value for a field.
    public enum Value: Hashable, Sendable, Codable {
        /// Text or a number.
        case text(String)
        /// A date.
        case date(year: Int, month: Int, day: Int)
    }

    /// Why text is not a usable template.
    public enum Problem: Error, Hashable, Sendable {
        /// Nothing is required: the template is empty or only optional.
        case nothingRequired
        /// A `{` or `}` has no partner, or the braces hold no field name.
        case unbalancedBraces
        /// A `[` or `]` has no partner.
        case unbalancedBrackets
        /// An optional part holds another.
        case nestedOptionalParts
        /// The field is not one the module knows.
        case unknownField(String)
        /// Fixed text holds `:`, which a name on screen cannot have.
        case containsPathSeparator
        /// A format is on a field that is no date, or is not a date format.
        case invalidFormat
    }

    /// One piece of a template.
    enum Part: Hashable, Sendable {
        case text(String)
        case field(Field, format: DateTemplate?)
        case optional([Part])
    }

    /// What stands for a required field without a value, for the user to fill in.
    public static let gap = "▮"
    /// A regular expression that fits nothing.
    private static let matchNothing = "(?!)"

    /// The template as it was written.
    public let text: String
    private let parts: [Part]

    init(text: String, parts: [Part]) {
        self.text = text
        self.parts = parts
    }

    /// Reads a template, for a module's fields.
    public static func parse(_ text: String, fields: [Field]) -> Result<NameTemplate, Problem> {
        var parser = NameTemplateParser(text: text, fields: fields)
        return parser.parse().map { NameTemplate(text: text, parts: $0) }
    }

    /// The name these values make, with single spaces. A required field without a value
    /// leaves a `gap`, and an optional part without one falls away. Without a value for
    /// any field that a module fills, it gives nil. The name has no extension and is not
    /// yet checked: `ProposedName` does that.
    public func name(from values: [String: Value]) -> String? {
        let moduleFields = Self.fields(in: parts).filter { $0.kind != .fixed }
        guard
            moduleFields.isEmpty
                || moduleFields.contains(where: { field in
                    Self.write(values[field.name], for: field, format: nil) != nil
                })
        else { return nil }
        let name = Self.fill(parts, with: values, leavingGaps: true) ?? ""
        return Self.singleSpaced(name)
    }

    /// Whether the template holds a field for a date, and that field has this value.
    public func uses(date value: Value, in values: [String: Value]) -> Bool {
        Self.fields(in: parts).contains { $0.kind == .date && values[$0.name] == value }
    }

    /// Whether a name without its extension fits this template. Fixed text and the
    /// `fixed` values, by field name, compare exactly as written. A fixed field
    /// without a value fits nothing, and neither does a name with stray spaces.
    public func matches(_ name: String, fixed: [String: String] = [:]) -> Bool {
        guard name == Self.singleSpaced(name) else { return false }
        let pattern = "^" + parts.map { Self.pattern(for: $0, fixed: fixed) }.joined() + "$"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let whole = NSRange(name.startIndex..., in: name)
        return expression.firstMatch(in: name, range: whole) != nil
    }

    /// The date in a name that fits this template, or nil when there is none.
    public func date(in name: String) -> Value? {
        let pattern = "^" + parts.map { Self.pattern(for: $0, fixed: [:]) }.joined() + "$"
        guard let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: name, range: NSRange(name.startIndex..., in: name)),
            match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: name),
            let format = Self.firstDateFormat(in: parts)
        else { return nil }
        return format.read(String(name[range]))
    }

    private static func firstDateFormat(in parts: [Part]) -> DateTemplate? {
        for part in parts {
            switch part {
            case .field(let field, let format) where field.kind == .date:
                return format ?? .standard
            case .optional(let inner):
                if let format = firstDateFormat(in: inner) { return format }
            default:
                continue
            }
        }
        return nil
    }

    private static func singleSpaced(_ text: String) -> String {
        text.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fields(in parts: [Part]) -> [Field] {
        parts.flatMap { part -> [Field] in
            switch part {
            case .text: []
            case .field(let field, _): [field]
            case .optional(let inner): fields(in: inner)
            }
        }
    }

    private static func fill(
        _ parts: [Part], with values: [String: Value], leavingGaps: Bool
    ) -> String? {
        var result = ""
        for part in parts {
            switch part {
            case .text(let text):
                result += text
            case .field(let field, let format):
                if let filled = write(values[field.name], for: field, format: format) {
                    result += filled
                } else if leavingGaps {
                    result += gap
                } else {
                    return nil
                }
            case .optional(let inner):
                result += fill(inner, with: values, leavingGaps: false) ?? ""
            }
        }
        return result
    }

    private static func write(_ value: Value?, for field: Field, format: DateTemplate?) -> String? {
        switch (value, field.kind) {
        case (.date(let year, let month, let day), .date):
            return (format ?? .standard).write(year: year, month: month, day: day)
        case (.text(let text), .number), (.text(let text), .text), (.text(let text), .fixed):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return nil
        }
    }

    private static func pattern(for part: Part, fixed: [String: String]) -> String {
        switch part {
        case .text(let text):
            return NSRegularExpression.escapedPattern(for: text)
        case .optional(let inner):
            return "(?:" + inner.map { pattern(for: $0, fixed: fixed) }.joined() + ")?"
        case .field(let field, let format):
            switch field.kind {
            // The group lets `date(in:)` find it; it is the template's only one.
            case .date: return "(" + (format ?? .standard).pattern + ")"
            case .number: return "[^ ]*[0-9][^ ]*"
            case .text: return ".+?"
            case .fixed:
                return fixed[field.name].map(NSRegularExpression.escapedPattern(for:))
                    ?? matchNothing
            }
        }
    }
}
