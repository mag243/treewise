import Foundation

/// Reads the text of a `NameTemplate`, one character at a time.
struct NameTemplateParser {
    /// A `/` is allowed, because it shows what a `:` is on disk, as in Finder.
    private static let pathSeparators: Set<Character> = [":"]

    private var rest: Substring
    private let fields: [NameTemplate.Field]
    private var required: [NameTemplate.Part] = []
    private var optional: [NameTemplate.Part]?
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
        case "[":
            guard optional == nil else { return .nestedOptionalParts }
            flushText()
            optional = []
            return nil
        case "]":
            guard let part = optional else { return .unbalancedBrackets }
            flushText()
            required.append(.optional(part))
            optional = nil
            return nil
        default:
            if Self.pathSeparators.contains(character) { return .containsPathSeparator }
            pendingText.append(character)
            return nil
        }
    }

    private mutating func readField() -> NameTemplate.Problem? {
        guard let end = rest.firstIndex(of: "}") else { return .unbalancedBraces }
        let inner = rest[..<end]
        rest = rest[rest.index(after: end)...]
        let pieces = inner.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let name = String(pieces[0])
        guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return .unbalancedBraces
        }
        guard let field = fields.first(where: { $0.name == name }) else {
            return .unknownField(name)
        }
        var format: DateTemplate?
        if pieces.count > 1 {
            guard field.kind == .date, let parsed = DateTemplate(String(pieces[1])) else {
                return .invalidFormat
            }
            format = parsed
        }
        flushText()
        append(.field(field, format: format))
        return nil
    }

    private mutating func flushText() {
        guard !pendingText.isEmpty else { return }
        append(.text(pendingText))
        pendingText = ""
    }

    private mutating func append(_ part: NameTemplate.Part) {
        if optional != nil {
            optional?.append(part)
        } else {
            required.append(part)
        }
    }

    private static func isRequirement(_ part: NameTemplate.Part) -> Bool {
        switch part {
        case .text(let text): !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .field: true
        case .optional: false
        }
    }
}
