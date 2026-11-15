import Foundation

/// Matching a whole name against a template's parts.
extension NameTemplate {
    /// The match of a whole name against parts without a choice of parts, with a group for
    /// the first date, year and sequence.
    static func match(_ name: String, _ parts: [Part], fixed: [String: String])
        -> NSTextCheckingResult?
    {
        matcher(for: parts, fixed: fixed)(name)
    }

    /// Matches names against parts without a choice of parts, as `match` does. The
    /// expression is compiled once, so matching many names, such as every name in a folder,
    /// costs one compilation.
    static func matcher(for parts: [Part], fixed: [String: String])
        -> (String) -> NSTextCheckingResult?
    {
        guard let (expression, _) = expression(for: parts, fixed: fixed, everyField: false)
        else { return { _ in nil } }
        return { name in Self.firstMatch(of: expression, in: name) }
    }

    /// The match, and with `everyField` the field of each of its groups.
    static func matchCapturing(
        _ name: String, _ parts: [Part], fixed: [String: String], everyField: Bool
    ) -> (match: NSTextCheckingResult, keys: [String])? {
        guard let (expression, keys) = expression(for: parts, fixed: fixed, everyField: everyField),
            let match = firstMatch(of: expression, in: name)
        else { return nil }
        return (match, keys)
    }

    /// The expression a whole name must match, and with `everyField` the field of each of
    /// its groups.
    private static func expression(
        for parts: [Part], fixed: [String: String], everyField: Bool
    ) -> (NSRegularExpression, [String])? {
        var captured = Capture(everyField: everyField)
        let body = parts.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
        guard let expression = try? NSRegularExpression(pattern: "^" + body + "$") else {
            return nil
        }
        return (expression, captured.keys)
    }

    private static func firstMatch(of expression: NSRegularExpression, in name: String)
        -> NSTextCheckingResult?
    {
        expression.firstMatch(in: name, range: NSRange(name.startIndex..., in: name))
    }
}
