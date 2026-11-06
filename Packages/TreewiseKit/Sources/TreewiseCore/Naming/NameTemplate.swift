import Foundation

/// A pattern for file names, written like `{date:yyyy.MM.dd} {company}[ - {number}]`:
/// fields, fixed text, and optional parts that fall away when a field is empty. A field can
/// name alternatives, as in `{number|company}`, and the first with a value is written.
/// A choice of parts, as in `<Sales {year}.Q{seq:4}|{text}>`, makes one name per part, and
/// `{year}` and `{seq}` continue the series of names that fit the same part. It both makes
/// a name from values and recognizes one, so Treewise can judge whether a name fits
/// without running a module or reading a file (ADR 0057, 0063, 0064).
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
            /// The year of a period, which Treewise supplies.
            case year
            /// A running number, which Treewise supplies.
            case sequence
        }

        /// The name of the folder that holds the item, for every module's templates.
        public static let folder = Field(name: "folder", kind: .fixed)
        /// The year of a series' next period, for every module's templates.
        public static let year = Field(name: "year", kind: .year)
        /// The next number of a series, for every module's templates.
        public static let seq = Field(name: "seq", kind: .sequence)
        /// The fields Treewise fills itself, which every module's templates can use.
        public static let suppliedByTreewise = [folder, year, seq]

        /// The name written between the braces.
        public let name: String
        /// What the field holds.
        public let kind: Kind

        /// Whether Treewise fills the field, and not a module.
        var isSuppliedByTreewise: Bool { [.fixed, .year, .sequence].contains(kind) }

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
        /// A `<` or `>` has no partner.
        case unbalancedAngleBrackets
        /// A choice of parts has an empty part.
        case emptyAlternative
        /// A choice of parts holds an optional part or another choice, or is inside one.
        case nestedChoiceOfParts
        /// The field is not one the module knows.
        case unknownField(String)
        /// Fixed text holds `:`, which a name on screen cannot have.
        case containsPathSeparator
        /// What follows `:` does not fit the field: a date format on a date, or a cycle
        /// of 2 or more on `{seq}`.
        case invalidFormat
    }

    /// What Treewise knows of an item and its folder, for the names a template makes.
    public struct Context: Hashable, Sendable {
        /// The names of the other items in the folder, without their extensions.
        public let siblingNames: [String]
        /// The item's name, without its extension.
        public let currentName: String
        /// The year of the item's date, for a period without a series to continue.
        public let fileYear: Int?

        /// Creates a context.
        public init(siblingNames: [String], currentName: String, fileYear: Int?) {
            self.siblingNames = siblingNames
            self.currentName = currentName
            self.fileYear = fileYear
        }

        /// No folder and no date.
        static let none = Context(siblingNames: [], currentName: "", fileYear: nil)
    }

    /// A name a template made.
    public struct MadeName: Hashable, Sendable {
        /// The name, without an extension.
        public let name: String
        /// Whether its `{year}` is the year of the file's date, which is to be checked.
        public let usesFileYear: Bool
    }

    /// One piece of a template.
    enum Part: Hashable, Sendable {
        case text(String)
        case field(Field, format: DateTemplate?)
        /// `{seq}`, which runs from 1 to `cycle` when one is given.
        case counter(cycle: Int?)
        /// Fields of which the first with a value is written (ADR 0063).
        case choice([Part])
        case optional([Part])
        /// Parts of which each makes a name of its own (ADR 0064).
        case alternatives([[Part]])
    }

    /// What stands for a required field without a value, for the user to fill in.
    public static let gap = "▮"

    /// The template as it was written.
    public let text: String
    let parts: [Part]

    /// Reads a template, for a module's fields and those in `Field.suppliedByTreewise`
    /// that are passed.
    public static func parse(_ text: String, fields: [Field]) -> Result<NameTemplate, Problem> {
        var parser = NameTemplateParser(text: text, fields: fields)
        return parser.parse().map { NameTemplate(text: text, parts: $0) }
    }

    /// The first name these values make, without a folder or a date: see `names`.
    public func name(from values: [String: Value]) -> String? {
        names(from: values, context: .none).first?.name
    }

    /// The names these values make, one per part of a choice of parts, with single spaces,
    /// in this order: the part the current name fits, the parts most names in the folder
    /// fit, and parts without fixed text last. A required field without a value leaves a
    /// `gap`, and an optional part without one falls away. A part whose module fields have
    /// no value at all gives no name. The names have no extension and are not yet checked:
    /// `ProposedName` does that.
    public func names(from values: [String: Value], context: Context) -> [MadeName] {
        let fixed = Self.fixedValues(in: values)
        return ordered(variants, context: context, fixed: fixed).compactMap { variant in
            make(variant.parts, from: values, context: context, fixed: fixed)
        }
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
        return variants.contains { Self.match(name, $0.parts, fixed: fixed) != nil }
    }

    /// The date in a name that fits this template, or nil when there is none.
    public func date(in name: String) -> Value? {
        for variant in variants {
            guard let match = Self.match(name, variant.parts, fixed: [:]) else { continue }
            guard let format = Self.firstDateFormat(in: variant.parts),
                let range = Range(match.range(withName: Self.dateGroup), in: name)
            else { return nil }
            return format.read(String(name[range]))
        }
        return nil
    }

    private func make(
        _ parts: [Part], from values: [String: Value], context: Context, fixed: [String: String]
    ) -> MadeName? {
        let moduleFields = Self.fields(in: parts).filter { !$0.isSuppliedByTreewise }
        guard
            moduleFields.isEmpty
                || moduleFields.contains(where: { field in
                    Self.write(values[field.name], for: field, format: nil) != nil
                })
        else { return nil }
        let period = Self.nextPeriod(for: parts, context: context, fixed: fixed)
        var all = values
        if let year = period.year { all[Field.year.name] = .text(String(year)) }
        if let seq = period.seq { all[Field.seq.name] = .text(seq) }
        let name = Self.fill(parts, with: all, leavingGaps: true) ?? ""
        return MadeName(name: Self.singleSpaced(name), usesFileYear: period.usesFileYear)
    }

    private static func fixedValues(in values: [String: Value]) -> [String: String] {
        guard case .text(let folder) = values[Field.folder.name] else { return [:] }
        return [Field.folder.name: folder]
    }

    static func singleSpaced(_ text: String) -> String {
        text.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fields(in parts: [Part]) -> [Field] {
        parts.flatMap { part -> [Field] in
            switch part {
            case .text: []
            case .field(let field, _): [field]
            case .counter: [Field.seq]
            case .optional(let inner), .choice(let inner): fields(in: inner)
            case .alternatives(let all): all.flatMap(fields(in:))
            }
        }
    }
}
