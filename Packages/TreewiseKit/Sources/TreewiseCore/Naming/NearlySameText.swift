import Foundation

/// Whether text in a name is nearly a pattern's fixed text or a folder's name: the same
/// but for a typo or a cut-off end (ADR 0067). Case does not count.
public enum NearlySameText {
    /// Shorter text has to be there exactly: one typo in `Tax` makes another word.
    private static let shortestWithTypo = 5
    /// From this length on, a second typo is forgiven.
    private static let shortestWithTwoTypos = 10
    /// A cut-off start has to be at least this long to say something.
    private static let shortestStart = 4
    /// The most characters a cut-off start may miss inside a word.
    private static let mostMissing = 2

    /// Whether `text` is nearly `expected`.
    ///
    /// - A typo is a character added, removed or replaced: one for text of at least 5
    ///   characters, two from 10 on. Digits have to be the same, as a different digit
    ///   usually means another year or number.
    /// - A cut-off is the start of `expected`, of at least 4 characters, ending where a
    ///   word of it ends or with at most 2 characters missing.
    public static func matches(_ text: String, _ expected: String) -> Bool {
        let text = Array(text.lowercased())
        let expected = Array(expected.lowercased())
        if text == expected { return true }
        return isCutOff(text, of: expected) || isTypo(text, of: expected)
    }

    /// The lengths text can have to be nearly `expected` characters long, the closest
    /// first, so a whole name is tried before a part of it.
    public static func lengths(near expected: Int) -> [Int] {
        guard expected >= shortestWithTypo else { return [expected] }
        let longest = expected + (expected >= shortestWithTwoTypos ? 2 : 1)
        return Array(Swift.min(shortestStart, expected)...longest)
            .sorted { abs($0 - expected) < abs($1 - expected) }
    }

    private static func isCutOff(_ text: [Character], of expected: [Character]) -> Bool {
        guard text.count >= shortestStart, text.count < expected.count,
            Array(expected.prefix(text.count)) == text
        else { return false }
        let next = expected[text.count]
        return expected.count - text.count <= mostMissing || !(next.isLetter || next.isNumber)
    }

    private static func isTypo(_ text: [Character], of expected: [Character]) -> Bool {
        guard expected.count >= shortestWithTypo,
            text.filter(\.isNumber) == expected.filter(\.isNumber)
        else { return false }
        let allowed = expected.count >= shortestWithTwoTypos ? 2 : 1
        return distance(text, expected, atMost: allowed) <= allowed
    }

    /// The fewest characters to add, remove or replace to make one text the other,
    /// counted up to one more than `limit`.
    private static func distance(_ one: [Character], _ other: [Character], atMost limit: Int)
        -> Int
    {
        guard abs(one.count - other.count) <= limit else { return limit + 1 }
        var previous = Array(0...other.count)
        for (row, character) in one.enumerated() {
            var current = [row + 1]
            for (column, otherCharacter) in other.enumerated() {
                current.append(
                    Swift.min(
                        previous[column + 1] + 1, current[column] + 1,
                        previous[column] + (character == otherCharacter ? 0 : 1)))
            }
            if current.min() ?? 0 > limit { return limit + 1 }
            previous = current
        }
        return previous[other.count]
    }
}
