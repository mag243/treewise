import Foundation

/// The rules of a file's name: which names an item may get (ADR 0018), and where a name's
/// extension starts, the one rule for the list, renaming, copy names and proposed names
/// (ADR 0109).
public enum FileName {
    /// File name extensions of two parts that count as one.
    private static let compoundExtensions = ["tar.gz", "tar.bz2", "tar.xz"]

    /// Splits a name into its stem and its extension with the dot (`.md`). Only files and
    /// packages have an extension; a name that starts with a dot is a stem only. A last part
    /// counts as an extension when it holds a letter and no space, so in `Payroll 2026.09`
    /// or `2026.04.28 Permit` the dot belongs to the name.
    ///
    /// Postcondition: `stem + pathExtension == name`.
    public static func split(_ name: String, kind: ItemKind) -> (
        stem: String, pathExtension: String
    ) {
        guard kind == .file || kind == .package else { return (name, "") }
        let lowercased = name.lowercased()
        for compound in compoundExtensions where lowercased.hasSuffix("." + compound) {
            let stem = name.dropLast(compound.count + 1)
            if !stem.isEmpty { return (String(stem), String(name.suffix(compound.count + 1))) }
        }
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex,
            isExtension(name[name.index(after: dot)...])
        else { return (name, "") }
        return (String(name[..<dot]), String(name[dot...]))
    }

    /// Whether a name can be given to an item: not empty or only spaces, not `.` or `..`,
    /// and without `/` or `:` (which Finder shows as each other).
    public static func isValid(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && name != "." && name != ".." && !name.contains("/")
            && !name.contains(":")
    }

    /// The name without its extension.
    public static func stem(of name: String, kind: ItemKind) -> String {
        split(name, kind: kind).stem
    }

    private static func isExtension(_ ending: Substring) -> Bool {
        !ending.contains(" ") && ending.contains(where: \.isLetter)
    }
}
