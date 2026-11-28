/// The changes a commit made to an item, or the changes on disk not committed yet, as
/// `git diff` shows them (ADR 0153): one file's for a file, each file's for a folder.
public struct GitDiff: Hashable, Sendable {
    /// Each file's changes, in git's order.
    public var files: [GitFileDiff]
    /// Whether it holds all of git's output; `false` for the first part of a very large
    /// diff, which Show All reads whole.
    public var isComplete: Bool

    /// Creates a diff of `files`.
    public init(files: [GitFileDiff] = [], isComplete: Bool = true) {
        self.files = files
        self.isComplete = isComplete
    }
}
