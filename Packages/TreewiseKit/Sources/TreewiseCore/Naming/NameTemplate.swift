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
            /// Digits, perhaps with letters before them, like `F26009`.
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
        /// Fixed text holds `/` or `:`, which could point somewhere else.
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

    /// The name these values make, or nil when a required field has no value. It has
    /// no extension and is not yet checked: `ProposedName` does that.
    public func name(from values: [String: Value]) -> String? {
        Self.fill(parts, with: values)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether a name without its extension fits this template. Fixed text and the
    /// `fixed` values, by field name, compare exactly as written. A fixed field
    /// without a value fits nothing.
    public func matches(_ name: String, fixed: [String: String] = [:]) -> Bool {
        let pattern = "^" + parts.map { Self.pattern(for: $0, fixed: fixed) }.joined() + "$"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let whole = NSRange(name.startIndex..., in: name)
        return expression.firstMatch(in: name, range: whole) != nil
    }

    private static func fill(_ parts: [Part], with values: [String: Value]) -> String? {
        var result = ""
        for part in parts {
            switch part {
            case .text(let text):
                result += text
            case .field(let field, let format):
                guard let filled = write(values[field.name], for: field, format: format) else {
                    return nil
                }
                result += filled
            case .optional(let inner):
                result += fill(inner, with: values) ?? ""
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
            case .date: return (format ?? .standard).pattern
            case .number: return "[A-Za-z]*[0-9]+"
            case .text: return ".+?"
            case .fixed:
                return fixed[field.name].map(NSRegularExpression.escapedPattern(for:))
                    ?? matchNothing
            }
        }
    }
}
