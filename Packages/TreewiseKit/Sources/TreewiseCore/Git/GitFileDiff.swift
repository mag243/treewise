/// One file's changes in a diff (ADR 0153).
///
/// Paths are relative to the repository's top folder, as git writes them.
public struct GitFileDiff: Hashable, Sendable {
    /// What happened to the file as a whole.
    public enum Change: Hashable, Sendable {
        /// It was not there before.
        case added
        /// It is not there after.
        case deleted
        /// Its contents changed in place.
        case modified
        /// It moved from the path it had, with or without other changes.
        case renamed(from: String)
    }

    /// Its path after the change; for a deleted file, the path it had.
    public let path: String
    /// What happened to it.
    public let change: Change
    /// Whether git shows no lines for it, as for a picture: "Binary file changed".
    public let isBinary: Bool
    /// The changed parts, each with a few lines around it; none for a binary file or a
    /// rename without other changes.
    public let hunks: [GitDiffHunk]

    /// Creates a file's changes.
    public init(path: String, change: Change, isBinary: Bool, hunks: [GitDiffHunk]) {
        self.path = path
        self.change = change
        self.isBinary = isBinary
        self.hunks = hunks
    }
}
