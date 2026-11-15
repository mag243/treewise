import Foundation

/// Finds a free name for an item that lands in a folder where its name is
/// taken: `Notes copy.md`, `Notes copy 2.md`, … (PLAN.md §4.2, ADR 0015).
public enum ConflictResolver {
    /// The word that marks a copy.
    private static let copySuffix = " copy"
    /// The first number added when the plain copy name is taken too.
    private static let firstCopyNumber = 2

    /// Returns `name` when no existing name matches it, otherwise the first free
    /// copy name. Names match case-insensitively and by canonical Unicode
    /// equivalence, as on a default APFS volume.
    ///
    /// Postcondition: the result matches none of `existing`.
    public static func availableName(
        for name: String, kind: ItemKind, among existing: some Sequence<String>
    ) -> String {
        let taken = Set(existing.map(comparisonKey))
        guard taken.contains(comparisonKey(name)) else { return name }
        let (base, pathExtension) = FileName.split(name, kind: kind)
        var number: Int?
        while true {
            let candidate = base + copySuffix + (number.map { " \($0)" } ?? "") + pathExtension
            if !taken.contains(comparisonKey(candidate)) { return candidate }
            number = (number ?? firstCopyNumber - 1) + 1
        }
    }

    /// The form two names share when the file system treats them as the same.
    public static func comparisonKey(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive, locale: nil)
    }
}
