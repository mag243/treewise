import Foundation

/// Reading a name that would fit but for a typo or a cut-off in its fixed text or the
/// folder's name (ADR 0067).
extension NameTemplate {
    /// The name of the loose group for the fixed text at `index`.
    private static func looseGroupName(_ index: Int) -> String { "fixed\(index)" }

    /// The name written right: with its fixed text and `fixed` values as the template
    /// writes them, where the name has them nearly (`NearlySameText`). Nil when the name
    /// already fits, or when it does not nearly fit.
    public func correctedName(_ name: String, fixed: [String: String] = [:]) -> String? {
        guard !matches(name, fixed: fixed) else { return nil }
        for variant in variants {
            if let corrected = Self.corrected(name, variant.parts, fixed: fixed),
                matches(corrected, fixed: fixed)
            {
                return corrected
            }
        }
        return nil
    }

    /// The most ways to place the loose groups that are tried for one name.
    private static let mostTries = 512

    private static func corrected(_ name: String, _ parts: [Part], fixed: [String: String])
        -> String?
    {
        var probe = Capture(everyField: false, loose: [])
        _ = parts.map { pattern(for: $0, fixed: fixed, captured: &probe) }
        let expected = probe.loose ?? []
        // A lazy group takes the shortest text that fits, which may be a cut-off part of
        // a whole name further on; so each group is tried with lengths, the closest first.
        for lengths in placements(for: expected) {
            if let result = corrected(name, parts, fixed: fixed, lengths: lengths) {
                return result
            }
        }
        return nil
    }

    private static func corrected(
        _ name: String, _ parts: [Part], fixed: [String: String], lengths: [Int]
    ) -> String? {
        var captured = Capture(everyField: false, loose: [], looseLengths: lengths)
        let body = parts.map { pattern(for: $0, fixed: fixed, captured: &captured) }.joined()
        guard let expression = try? NSRegularExpression(pattern: "^" + body + "$"),
            let match = expression.firstMatch(
                in: name, range: NSRange(name.startIndex..., in: name))
        else { return nil }
        var result = name
        // From the end, so the ranges before stay where they are.
        for (index, expected) in (captured.loose ?? []).enumerated().reversed() {
            guard let range = Range(match.range(withName: looseGroupName(index)), in: name)
            else { continue }
            guard NearlySameText.matches(String(name[range]), expected) else { return nil }
            result.replaceSubrange(range, with: expected)
        }
        return result == name ? nil : result
    }

    /// The lengths to try for the loose groups together, those closest to the expected
    /// texts first.
    private static func placements(for expected: [String]) -> [[Int]] {
        var placements: [Placement] = [Placement(rank: 0, lengths: [])]
        for text in expected {
            let lengths = NearlySameText.lengths(near: text.count)
            var next: [Placement] = []
            for placement in placements {
                for (rank, length) in lengths.enumerated() {
                    next.append(
                        Placement(
                            rank: placement.rank + rank, lengths: placement.lengths + [length]))
                }
            }
            placements = Array(next.sorted { $0.rank < $1.rank }.prefix(mostTries))
        }
        return placements.map(\.lengths)
    }

    /// Lengths for the loose groups, ranked by how far they are from the expected texts.
    private struct Placement {
        let rank: Int
        let lengths: [Int]
    }

    /// Fixed text with its words in a loose group, and the spaces and punctuation around
    /// them as written, as those separate the fields.
    static func loosePattern(for text: String, _ captured: inout Capture) -> String {
        let isWord: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        guard let first = text.firstIndex(where: isWord), let last = text.lastIndex(where: isWord)
        else { return NSRegularExpression.escapedPattern(for: text) }
        return NSRegularExpression.escapedPattern(for: String(text[..<first]))
            + looseGroup(for: String(text[first...last]), &captured)
            + NSRegularExpression.escapedPattern(for: String(text[text.index(after: last)...]))
    }

    /// A group that takes any text, to be compared with `expected` afterwards.
    static func looseGroup(for expected: String, _ captured: inout Capture) -> String {
        let index = captured.loose?.count ?? 0
        captured.loose?.append(expected)
        let body =
            captured.looseLengths.indices.contains(index)
            ? ".{\(captured.looseLengths[index])}" : ".+?"
        return "(?<\(looseGroupName(index))>" + body + ")"
    }
}
