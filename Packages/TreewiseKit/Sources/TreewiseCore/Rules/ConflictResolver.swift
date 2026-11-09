import Foundation

/// Finds a free name for an item that lands in a folder where its name is
/// taken: `Notes copy.md`, `Notes copy 2.md`, … (PLAN.md §4.2, ADR 0015).
public enum ConflictResolver {
    /// File name extensions of two parts that count as one.
    private static let compoundExtensions = ["tar.gz", "tar.bz2", "tar.xz"]
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
        let (base, pathExtension) = split(name, kind: kind)
        var number: Int?
        while true {
            let candidate = base + copySuffix + (number.map { " \($0)" } ?? "") + pathExtension
            if !taken.contains(comparisonKey(candidate)) { return candidate }
            number = (number ?? firstCopyNumber - 1) + 1
        }
    }

    /// Splits a name into the part before its extension and the extension with
    /// its dot (`.md`); the extension is empty when the name has none.
    static func split(_ name: String, kind: ItemKind) -> (String, String) {
        guard kind != .folder else { return (name, "") }
        let lowercased = name.lowercased()
        for compound in compoundExtensions where lowercased.hasSuffix("." + compound) {
            let base = name.dropLast(compound.count + 1)
            if !base.isEmpty { return (String(base), String(name.suffix(compound.count + 1))) }
        }
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex,
            isExtension(name[name.index(after: dot)...])
        else { return (name, "") }
        return (String(name[..<dot]), String(name[dot...]))
    }

    /// Whether the text after a name's last dot is an extension. In a name like
    /// `2026.04.28 Permit` or `Payroll 2026.09` the dot belongs to the name.
    private static func isExtension(_ ending: Substring) -> Bool {
        !ending.contains(" ") && ending.contains(where: \.isLetter)
    }

    /// The form two names share when the file system treats them as the same.
    public static func comparisonKey(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive, locale: nil)
    }
}
