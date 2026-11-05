import Foundation

/// Turns what a module proposes or a user types into a name that can reach a
/// file (ADR 0057).
public enum ProposedName {
    /// The longest name APFS accepts, in UTF-8 bytes.
    public static let maximumByteCount = 255
    /// What a name on screen cannot hold. On disk a `:` is a `/` on screen, as in Finder,
    /// so a `/` on screen cannot point to another folder.
    private static let pathSeparators = CharacterSet(charactersIn: ":")

    /// Returns the full name for a proposal: trimmed, and with the item's
    /// extension unless the proposal has it already.
    ///
    /// Postcondition: a success is valid by `problem(inEdit:)` and starts without a dot.
    public static func resolve(
        _ proposal: NameProposal, for original: String, kind: ItemKind
    ) -> Result<String, ProposedNameProblem> {
        let trimmed = proposal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let problem = problem(inEdit: trimmed) { return .failure(problem) }
        if trimmed.hasPrefix(".") { return .failure(.startsWithDot) }
        let (_, pathExtension) = ConflictResolver.split(original, kind: kind)
        let hasExtension = trimmed.lowercased().hasSuffix(pathExtension.lowercased())
        let name = hasExtension ? trimmed : trimmed + pathExtension
        if name.utf8.count > maximumByteCount { return .failure(.tooLong) }
        return .success(name)
    }

    /// A file's name without its extension.
    public static func stem(of name: String) -> String {
        ConflictResolver.split(name, kind: .file).0
    }

    /// A name as it goes on disk, from how it is shown.
    public static func diskName(fromShown name: String) -> String {
        name.replacingOccurrences(of: "/", with: ":")
    }

    /// A name as it is shown, from how it is on disk.
    public static func shownName(fromDisk name: String) -> String {
        name.replacingOccurrences(of: ":", with: "/")
    }

    /// The name without double spaces or spaces around it, keeping its extension, or
    /// nil when it has none of those.
    public static func repairingSpaces(in name: String) -> String? {
        let (stem, pathExtension) = ConflictResolver.split(name, kind: .file)
        let clean =
            stem.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let repaired = clean + pathExtension
        return repaired == name ? nil : repaired
    }

    /// The problem with a name as it stands, or nil when it can be used. A user
    /// may choose a name with a leading dot, so this does not refuse one.
    public static func problem(inEdit name: String) -> ProposedNameProblem? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        if name.rangeOfCharacter(from: pathSeparators) != nil { return .containsPathSeparator }
        if name.rangeOfCharacter(from: .controlCharacters) != nil {
            return .containsControlCharacter
        }
        if name.utf8.count > maximumByteCount { return .tooLong }
        return nil
    }
}
