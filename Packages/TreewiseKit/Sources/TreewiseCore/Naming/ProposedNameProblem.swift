/// Why a proposed or edited name cannot be used (ADR 0057).
public enum ProposedNameProblem: Error, Hashable, Sendable {
    /// There is no name yet: no proposal has arrived and nothing was typed.
    case noName
    /// The name is the one the item already has.
    case unchanged
    /// A required field is still a gap, to be filled in.
    case hasGap
    /// The name is empty or only whitespace.
    case empty
    /// The name holds `:`, which is what a `/` becomes on disk.
    case containsPathSeparator
    /// The name holds a control character.
    case containsControlCharacter
    /// A proposal starts with a dot, which would hide the file.
    case startsWithDot
    /// The name is longer than a file system allows.
    case tooLong
}
