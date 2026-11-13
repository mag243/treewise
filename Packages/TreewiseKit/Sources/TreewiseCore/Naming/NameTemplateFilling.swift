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
        /// With `everyField`, the field each plain group stands for, in the order of the groups.
        var keys: [String] = []
        /// The field a choice of fields counts as while it is built: its first.
        var tokenKey: String?
        /// For a name that nearly fits, the text each loose group should hold, in the
        /// order of the groups; nil when fixed text has to be there exactly.
        var loose: [String]?
        /// The length each loose group takes, when it is tried with lengths.
        var looseLengths: [Int] = []

        /// Notes a plain group for `field`, or for the choice it belongs to.
        mutating func addGroup(for field: String) {
            keys.append(tokenKey ?? field)
        }
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

    /// The parts written with these values. An optional part without a field is written only
    /// when `current`, the item's name, holds its text (ADR 0064).
    static func fill(
        _ parts: [Part], with values: [String: Value], current: String, leavingGaps: Bool
    ) -> String? {
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
                    alternatives.lazy.compactMap {
                        fill([$0], with: values, current: current, leavingGaps: false)
                    }
                    .first
            case .alternatives(let all):
                filled = all.first.flatMap {
                    fill($0, with: values, current: current, leavingGaps: leavingGaps)
                }
            case .optional(let inner):
                filled = fillOptional(inner, with: values, current: current)
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

    private static func fillOptional(
        _ inner: [Part], with values: [String: Value], current: String
    ) -> String {
        guard fields(in: inner).isEmpty else {
            return fill(inner, with: values, current: current, leavingGaps: false) ?? ""
        }
        let text = inner.map { part in
            if case .text(let text) = part { return text }
            return ""
        }.joined()
        return holds(current, text) ? text : ""
    }

    /// Whether `name` holds `text`, without the spaces and punctuation at its ends, as whole
    /// words and ignoring case and accents. Text without letters or digits is held by no name.
    static func holds(_ name: String, _ text: String) -> Bool {
        let core = text.trimmingCharacters(
            in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard core.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else {
            return false
        }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var searched = name.startIndex..<name.endIndex
        while let found = name.range(of: core, options: options, range: searched) {
            let before =
                found.lowerBound == name.startIndex
                ? nil : name[name.index(before: found.lowerBound)]
            let after = found.upperBound == name.endIndex ? nil : name[found.upperBound]
            if !isWordCharacter(before), !isWordCharacter(after) { return true }
            searched = name.index(after: found.lowerBound)..<name.endIndex
        }
        return false
    }

    private static func isWordCharacter(_ character: Character?) -> Bool {
        character.map { $0.isLetter || $0.isNumber } ?? false
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
    static func match(_ name: String, _ parts: [Part], fixed: [String: String])
        -> NSTextCheckingResult?
    {
        matchCapturing(name, parts, fixed: fixed, everyField: false)?.match
    }

    /// The match, and with `everyField` the field of each of its groups.
    static func matchCapturing(
        _ name: String, _ parts: [Part], fixed: [String: String], everyField: Bool
    ) -> (match: NSTextCheckingResult, keys: [String])? {
        var captured = Capture(everyField: everyField)
        let body = parts.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
        guard let expression = try? NSRegularExpression(pattern: "^" + body + "$"),
            let match = expression.firstMatch(
                in: name, range: NSRange(name.startIndex..., in: name))
        else { return nil }
        return (match, captured.keys)
    }

    static func pattern(
        for part: Part, fixed: [String: String], captured: inout Capture
    )
        -> String
    {
        switch part {
        case .text(let text):
            return captured.loose == nil
                ? NSRegularExpression.escapedPattern(for: text) : loosePattern(for: text, &captured)
        case .optional(let inner):
            return "(?:"
                + inner.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
                + ")?"
        case .choice(let inner):
            captured.tokenKey = fields(in: inner).first?.name
            defer { captured.tokenKey = nil }
            return "(?:"
                + inner.map { pattern(for: $0, fixed: fixed, captured: &captured) }
                .joined(separator: "|") + ")"
        case .alternatives(let all):
            return "(?:"
                + all.map {
                    $0.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
                }
                .joined(separator: "|") + ")"
        case .counter(let series):
            return group(seqGroup, series.pattern, field: Field.seq.name, captured: &captured)
        case .field(let field, let format):
            return pattern(for: field, format: format, fixed: fixed, captured: &captured)
        }
    }

    private static func pattern(
        for field: Field, format: DateTemplate?, fixed: [String: String],
        captured: inout Capture
    ) -> String {
        switch field.kind {
        case .date:
            return group(
                dateGroup, (format ?? .standard).pattern, field: field.name, captured: &captured)
        case .year: return group(yearGroup, "[0-9]{4}", field: field.name, captured: &captured)
        case .sequence: return group(seqGroup, "[0-9]+", field: field.name, captured: &captured)
        case .number: return plain("[^ ]*[0-9][^ ]*", field: field.name, captured: &captured)
        case .text: return plain(".+?", field: field.name, captured: &captured)
        case .fixed:
            guard let value = fixed[field.name] else { return matchNothing }
            if captured.loose != nil { return looseGroup(for: value, &captured) }
            let body = NSRegularExpression.escapedPattern(for: value)
            guard captured.everyField else { return body }
            captured.addGroup(for: field.name)
            return "(" + body + ")"
        }
    }

    /// A named group for the first field of its kind, so a name can be read back.
    /// A field's pattern, in a plain group when every field is captured. Then a field may
    /// also be a gap, as in a proposal it could not fill in.
    private static func plain(_ body: String, field: String, captured: inout Capture) -> String {
        guard captured.everyField else { return body }
        captured.addGroup(for: field)
        return "(" + body + "|" + NSRegularExpression.escapedPattern(for: gap) + ")"
    }

    private static func group(
        _ name: String, _ body: String, field: String, captured: inout Capture
    ) -> String {
        if captured.everyField { return plain(body, field: field, captured: &captured) }
        guard captured.named.insert(name).inserted else { return "(?:" + body + ")" }
        return "(?<" + name + ">" + body + ")"
    }
}
