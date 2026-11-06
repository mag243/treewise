import Foundation

/// How a template writes values and recognizes names.
extension NameTemplate {
    /// The template with each choice of parts resolved to one of its parts.
    struct Variant: Hashable, Sendable {
        let parts: [Part]
        /// Whether every chosen part holds fixed text, so it says something of its own.
        let hasFixedText: Bool
    }

    /// The names of the groups a pattern captures, each for its first field.
    static let dateGroup = "date"
    static let yearGroup = "year"
    static let seqGroup = "seq"
    /// Which groups a pattern captures: a named group for the first date, year and
    /// sequence, or a plain group for every field a module or the series fills.
    struct Capture {
        var named: Set<String> = []
        let everyField: Bool
    }

    /// A regular expression that fits nothing.
    private static let matchNothing = "(?!)"

    /// Every way to resolve the template's choices of parts, in the order they are written.
    var variants: [Variant] {
        parts.reduce([Variant(parts: [], hasFixedText: true)]) { variants, part in
            guard case .alternatives(let alternatives) = part else {
                return variants.map {
                    Variant(parts: $0.parts + [part], hasFixedText: $0.hasFixedText)
                }
            }
            return variants.flatMap { variant in
                alternatives.map { alternative in
                    Variant(
                        parts: variant.parts + alternative,
                        hasFixedText: variant.hasFixedText && Self.holdsFixedText(alternative))
                }
            }
        }
    }

    /// The variants in the order their names are offered (ADR 0064).
    func ordered(_ variants: [Variant], context: Context, fixed: [String: String]) -> [Variant] {
        guard variants.count > 1 else { return variants }
        let keyed = variants.enumerated().map { index, variant in
            let fitsCurrent =
                variant.hasFixedText
                && Self.match(context.currentName, variant.parts, fixed: fixed) != nil
            let fitting = context.siblingNames.count {
                Self.match($0, variant.parts, fixed: fixed) != nil
            }
            return (
                key: (fitsCurrent ? 0 : 1, variant.hasFixedText ? 0 : 1, -fitting, index),
                variant: variant
            )
        }
        return keyed.sorted { $0.key < $1.key }.map(\.variant)
    }

    private static func holdsFixedText(_ parts: [Part]) -> Bool {
        parts.contains { part in
            if case .text(let text) = part {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return false
        }
    }

    static func firstDateFormat(in parts: [Part]) -> DateTemplate? {
        for part in parts {
            switch part {
            case .field(let field, let format) where field.kind == .date:
                return format ?? .standard
            case .optional(let inner), .choice(let inner):
                if let format = firstDateFormat(in: inner) { return format }
            case .alternatives(let all):
                if let format = all.lazy.compactMap(firstDateFormat(in:)).first { return format }
            default:
                continue
            }
        }
        return nil
    }

    static func fill(_ parts: [Part], with values: [String: Value], leavingGaps: Bool) -> String? {
        var result = ""
        for part in parts {
            let filled: String?
            switch part {
            case .text(let text):
                filled = text
            case .field(let field, let format):
                filled = write(values[field.name], for: field, format: format)
            case .counter:
                filled = write(values[Field.seq.name], for: Field.seq, format: nil)
            case .choice(let alternatives):
                filled =
                    alternatives.lazy.compactMap { fill([$0], with: values, leavingGaps: false) }
                    .first
            case .alternatives(let all):
                filled = all.first.flatMap { fill($0, with: values, leavingGaps: leavingGaps) }
            case .optional(let inner):
                filled = fill(inner, with: values, leavingGaps: false) ?? ""
            }
            if let filled {
                result += filled
            } else if leavingGaps {
                result += gap
            } else {
                return nil
            }
        }
        return result
    }

    static func write(_ value: Value?, for field: Field, format: DateTemplate?) -> String? {
        switch (value, field.kind) {
        case (.date(let year, let month, let day), .date):
            return (format ?? .standard).write(year: year, month: month, day: day)
        case (.text(let text), .number), (.text(let text), .text), (.text(let text), .fixed),
            (.text(let text), .year), (.text(let text), .sequence):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return nil
        }
    }

    /// The match of a whole name against parts without a choice of parts, with a group for
    /// the first date, year and sequence.
    static func match(
        _ name: String, _ parts: [Part], fixed: [String: String], everyField: Bool = false
    ) -> NSTextCheckingResult? {
        var captured = Capture(everyField: everyField)
        let body = parts.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
        guard let expression = try? NSRegularExpression(pattern: "^" + body + "$") else {
            return nil
        }
        return expression.firstMatch(in: name, range: NSRange(name.startIndex..., in: name))
    }

    private static func pattern(
        for part: Part, fixed: [String: String], captured: inout Capture
    )
        -> String
    {
        switch part {
        case .text(let text):
            return NSRegularExpression.escapedPattern(for: text)
        case .optional(let inner):
            return "(?:"
                + inner.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
                + ")?"
        case .choice(let inner):
            return "(?:"
                + inner.map { pattern(for: $0, fixed: fixed, captured: &captured) }
                .joined(separator: "|") + ")"
        case .alternatives(let all):
            return "(?:"
                + all.map {
                    $0.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
                }
                .joined(separator: "|") + ")"
        case .counter:
            return group(seqGroup, "[0-9]+", captured: &captured)
        case .field(let field, let format):
            return pattern(for: field, format: format, fixed: fixed, captured: &captured)
        }
    }

    private static func pattern(
        for field: Field, format: DateTemplate?, fixed: [String: String],
        captured: inout Capture
    ) -> String {
        switch field.kind {
        case .date: return group(dateGroup, (format ?? .standard).pattern, captured: &captured)
        case .year: return group(yearGroup, "[0-9]{4}", captured: &captured)
        case .sequence: return group(seqGroup, "[0-9]+", captured: &captured)
        case .number: return captured.everyField ? "([^ ]*[0-9][^ ]*)" : "[^ ]*[0-9][^ ]*"
        case .text: return captured.everyField ? "(.+?)" : ".+?"
        case .fixed:
            return fixed[field.name].map(NSRegularExpression.escapedPattern(for:)) ?? matchNothing
        }
    }

    /// A named group for the first field of its kind, so a name can be read back.
    private static func group(_ name: String, _ body: String, captured: inout Capture) -> String {
        if captured.everyField { return "(" + body + ")" }
        guard captured.named.insert(name).inserted else { return "(?:" + body + ")" }
        return "(?<" + name + ">" + body + ")"
    }
}
