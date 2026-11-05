import Foundation

/// Names for new folders, and which names an item may get (ADR 0018).
public enum FolderNaming {
    /// The first number added when the plain name is taken.
    private static let firstNumber = 2

    /// Returns "untitled folder", or "untitled folder 2", 3, … when taken, in
    /// the language of `locale`. Names compare as on APFS: case-insensitively.
    ///
    /// Postcondition: the result matches none of `existing`.
    public static func newFolderName(among existing: some Sequence<String>, locale: Locale)
        -> String
    {
        let base = String(
            localized: "untitled folder", bundle: .module.localizationBundle(for: locale),
            locale: locale,
            comment: "Name of a new folder")
        let taken = Set(existing.map { $0.folding(options: .caseInsensitive, locale: nil) })
        var candidate = base
        var number = firstNumber
        while taken.contains(candidate.folding(options: .caseInsensitive, locale: nil)) {
            candidate = "\(base) \(number)"
            number += 1
        }
        return candidate
    }

    /// Whether a name can be given to an item: not empty or only spaces, not
    /// `.` or `..`, and without `/` or `:` (which Finder shows as each other).
    public static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && name != "." && name != ".." && !name.contains("/")
            && !name.contains(":")
    }
}
