import Foundation

/// Whether a folder's name is nearly another's, as a spelling error in the year before is
/// nearly the name written right in this year (ADR 0139).
///
/// The rules, in this order:
/// 1. The same but for case, spaces, `-`, `_` and diacritics: nearly the same.
/// 2. Other digits: another folder, as `Q1` and `Q2`.
/// 3. Both spelled correctly: two words, as `Bonnen` and `Bonen`.
/// 4. A typo of the other as `NearlySameText` counts typos (ADR 0067), without its cut-off
///    start, since `Belasting` and `Belastingdienst` are likely two folders.
/// 5. The years' history over the rules above: two names side by side in a year are two
///    folders; two never side by side, one in more years, are one folder within two typos
///    that leave at least half of the shorter name, even when short or spelled correctly,
///    as `Huur` in one year and `Huis` in five.
public enum NearlySameFolderName {
    /// The characters that do not tell two folders apart.
    private static let ignored: Set<Character> = ["-", "_"]

    /// The most typos the years' history forgives.
    private static let mostTyposByHistory = 2

    /// Whether `one` is nearly `other`, `isSpelledCorrectly` telling whether a name is
    /// spelled correctly in the user's languages, and `history` where the names stand.
    public static func matches(
        _ one: String, _ other: String, isSpelledCorrectly: (String) -> Bool,
        history: FolderNameHistory = FolderNameHistory()
    ) -> Bool {
        if history.areSideBySide(one, other) { return false }
        let first = key(one)
        let second = key(other)
        if first == second { return true }
        guard first.filter(\.isNumber) == second.filter(\.isNumber) else { return false }
        if history.takesOneForTheOther(one, other) {
            let typos = NearlySameText.distance(
                Array(first), Array(second), atMost: mostTyposByHistory)
            return typos <= mostTyposByHistory && 2 * typos <= min(first.count, second.count)
        }
        guard !(isSpelledCorrectly(one) && isSpelledCorrectly(other)) else { return false }
        return NearlySameText.isTypo(first, of: second)
            || NearlySameText.isTypo(second, of: first)
    }

    /// The name without what does not tell two folders apart.
    private static func key(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: nil
            )
            .filter { !$0.isWhitespace && !ignored.contains($0) }
    }
}
