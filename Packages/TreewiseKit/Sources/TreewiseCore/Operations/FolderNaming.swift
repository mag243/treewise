import Foundation

/// Names for new folders (ADR 0018).
public enum FolderNaming {
    /// The first number added when the plain name is taken.
    private static let firstNumber = 2

    /// Returns "untitled folder", or "untitled folder 2", 3, … when taken, in
    /// the language of `locale`. Names compare as on APFS, as `ConflictResolver`
    /// compares them: case-insensitively and Unicode-normalised.
    ///
    /// Postcondition: the result matches none of `existing`.
    public static func newFolderName(among existing: some Sequence<String>, locale: Locale)
        -> String
    {
        let base = String(
            localized: "untitled folder", bundle: .module.localizationBundle(for: locale),
            locale: locale,
            comment: "Name of a new folder")
        let taken = Set(existing.map(ConflictResolver.comparisonKey))
        var candidate = base
        var number = firstNumber
        while taken.contains(ConflictResolver.comparisonKey(candidate)) {
            candidate = "\(base) \(number)"
            number += 1
        }
        return candidate
    }
}
