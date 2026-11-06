import Foundation

/// Which part of a name each field filled in, and where the fields sit in a template's
/// text, so the two can share a colour per field.
extension NameTemplate {
    /// A part of a name that a field filled in, or a field in a template's text.
    public struct FieldMark: Hashable, Sendable {
        /// The field: the first of a choice of fields, so a choice is one field.
        public let key: String
        /// Where it sits.
        public let range: Range<String.Index>
    }

    /// The parts of a name without its extension that fields filled in, in the first part
    /// of a choice of parts that it fits. `{folder}` and fixed text are not marked, and a
    /// name that does not fit gives none.
    public func fieldMarks(in name: String, fixed: [String: String] = [:]) -> [FieldMark] {
        for variant in variants {
            guard
                let (match, keys) = Self.matchCapturing(
                    name, variant.parts, fixed: fixed, everyField: true)
            else { continue }
            return keys.enumerated().compactMap { index, key in
                Range(match.range(at: index + 1), in: name).map { FieldMark(key: key, range: $0) }
            }
        }
        return []
    }

    /// The fields in a template's text, `{folder}` left out, as they are written, so text
    /// being typed can show them too; an unfinished field is none yet.
    public static func fieldTokens(in text: String) -> [FieldMark] {
        var tokens: [FieldMark] = []
        var rest = text[...]
        while let open = rest.firstIndex(of: "{"),
            let close = rest[open...].firstIndex(of: "}")
        {
            let inner = text[text.index(after: open)..<close]
            let key = String(inner.prefix { $0 != "|" && $0 != ":" })
            if !key.isEmpty, key != Field.folder.name {
                tokens.append(FieldMark(key: key, range: open..<text.index(after: close)))
            }
            rest = text[text.index(after: close)...]
        }
        return tokens
    }

    /// The fields of a template's text in the order they first appear, which gives each
    /// its colour.
    public static func fieldOrder(in text: String) -> [String] {
        var seen: Set<String> = []
        return fieldTokens(in: text).map(\.key).filter { seen.insert($0).inserted }
    }
}
