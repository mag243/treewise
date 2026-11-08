import Foundation

/// Reads the text of a `NameTemplate`, one character at a time.
struct NameTemplateParser {
    /// A `/` is allowed, because it shows what a `:` is on disk, as in Finder.
    private static let pathSeparators: Set<Character> = [":"]
    /// The shortest cycle `{seq}` can have.
    private static let shortestCycle = 2

    private var rest: Substring
    private let fields: [NameTemplate.Field]
    private var required: [NameTemplate.Part] = []
    private var optional: [NameTemplate.Part]?
    /// The parts of a choice of parts being read, and the one being read now.
    private var alternatives: [[NameTemplate.Part]]?
    private var alternative: [NameTemplate.Part] = []
    private var pendingText = ""

    init(text: String, fields: [NameTemplate.Field]) {
        rest = Substring(text)
        self.fields = fields
    }

    /// Returns the parts, or the first problem found.
    mutating func parse() -> Result<[NameTemplate.Part], NameTemplate.Problem> {
        while let character = rest.popFirst() {
            if let problem = read(character) { return .failure(problem) }
        }
        flushText()
        if optional != nil { return .failure(.unbalancedBrackets) }
        if alternatives != nil { return .failure(.unbalancedAngleBrackets) }
        guard required.contains(where: Self.isRequirement) else {
            return .failure(.nothingRequired)
        }
        return .success(required)
    }

    private mutating func read(_ character: Character) -> NameTemplate.Problem? {
        switch character {
        case "{":
            return readField()
        case "}":
            return .unbalancedBraces
        case "[", "]":
            return readOptional(opening: character == "[")
        case "<", ">":
            return readChoice(opening: character == "<")
        case "|" where alternatives != nil:
            return endAlternative()
        default:
            if Self.pathSeparators.contains(character) { return .containsPathSeparator }
            pendingText.append(character)
            return nil
        }
    }

    private mutating func readOptional(opening: Bool) -> NameTemplate.Problem? {
        if opening {
            if alternatives != nil { return .nestedChoiceOfParts }
            guard optional == nil else { return .nestedOptionalParts }
            flushText()
            optional = []
            return nil
        }
        guard optional != nil else { return .unbalancedBrackets }
        // The text before `]` belongs to the part, so it is added before the part is read.
        flushText()
        required.append(.optional(optional ?? []))
        optional = nil
        return nil
    }

    private mutating func readChoice(opening: Bool) -> NameTemplate.Problem? {
        if opening {
            guard optional == nil, alternatives == nil else { return .nestedChoiceOfParts }
            flushText()
            alternatives = []
            alternative = []
            return nil
        }
        guard alternatives != nil else { return .unbalancedAngleBrackets }
        if let problem = endAlternative() { return problem }
        required.append(.alternatives(alternatives ?? []))
        alternatives = nil
        return nil
    }

    private mutating func endAlternative() -> NameTemplate.Problem? {
        flushText()
        guard !alternative.isEmpty else { return .emptyAlternative }
        alternatives?.append(alternative)
        alternative = []
        return nil
    }

    /// Reads a field, or a choice of fields separated by `|` (ADR 0063).
    private mutating func readField() -> NameTemplate.Problem? {
        guard let end = rest.firstIndex(of: "}") else { return .unbalancedBraces }
        let inner = rest[..<end]
        rest = rest[rest.index(after: end)...]
        var choices: [NameTemplate.Part] = []
        for piece in inner.split(separator: "|", omittingEmptySubsequences: false) {
            switch field(in: piece) {
            case .success(let part): choices.append(part)
            case .failure(let problem): return problem
            }
        }
        flushText()
        append(choices.count == 1 ? choices[0] : .choice(choices))
        return nil
    }

    /// One field with what follows its `:`, as written between braces or between `|`.
    private func field(in text: Substring) -> Result<NameTemplate.Part, NameTemplate.Problem> {
        let pieces = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let name = String(pieces[0])
        guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return .failure(.unbalancedBraces)
        }
        guard let field = fields.first(where: { $0.name == name }) else {
            return .failure(.unknownField(name))
        }
        let after = pieces.count > 1 ? String(pieces[1]) : nil
        switch field.kind {
        case .sequence:
            guard let after else { return .success(.counter(cycle: nil)) }
            guard let cycle = Int(after), cycle >= Self.shortestCycle else {
                return .failure(.invalidFormat)
            }
            return .success(.counter(cycle: cycle))
        case .date:
            guard let after else { return .success(.field(field, format: nil)) }
            guard let format = DateTemplate(after) else { return .failure(.invalidFormat) }
            return .success(.field(field, format: format))
        case .number, .text, .fixed, .year:
            return after == nil ? .success(.field(field, format: nil)) : .failure(.invalidFormat)
        }
    }

    private mutating func flushText() {
        guard !pendingText.isEmpty else { return }
        append(.text(pendingText))
        pendingText = ""
    }

    private mutating func append(_ part: NameTemplate.Part) {
        if optional != nil {
            optional?.append(part)
        } else if alternatives != nil {
            alternative.append(part)
        } else {
            required.append(part)
        }
    }

    private static func isRequirement(_ part: NameTemplate.Part) -> Bool {
        switch part {
        case .text(let text): !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .field, .choice, .counter, .alternatives: true
        case .optional: false
        }
    }
}
