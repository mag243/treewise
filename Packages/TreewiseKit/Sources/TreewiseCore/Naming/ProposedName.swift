import Foundation

/// Turns what a module proposes or a user types into a name that can reach a
/// file (ADR 0057).
public enum ProposedName {
    /// The longest name APFS accepts, in UTF-8 bytes.
    public static let maximumByteCount = 255
    /// Characters that could make a name point to another place.
    private static let pathSeparators = CharacterSet(charactersIn: "/:")

    /// Returns the full name for a proposal: trimmed, and with the item's
    /// extension unless the proposal has it already or replaces it.
    ///
    /// Postcondition: a success is valid by `problem(inEdit:)` and starts without a dot.
    public static func resolve(
        _ proposal: NameProposal, for original: String, kind: ItemKind
    ) -> Result<String, ProposedNameProblem> {
        let trimmed = proposal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let problem = problem(inEdit: trimmed) { return .failure(problem) }
        if trimmed.hasPrefix(".") { return .failure(.startsWithDot) }
        let (_, pathExtension) = ConflictResolver.split(original, kind: kind)
        let keepsName =
            proposal.replacesExtension
            || trimmed.lowercased().hasSuffix(pathExtension.lowercased())
        let name = keepsName ? trimmed : trimmed + pathExtension
        if name.utf8.count > maximumByteCount { return .failure(.tooLong) }
        return .success(name)
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
