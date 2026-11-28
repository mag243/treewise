/// Reads an item's git history without changing the repository (ADR 0153).
///
/// Paths are relative to the repository's top folder, as `GitStatusReading.relativePath`
/// gives them; the top folder's is empty.
public protocol GitHistoryReading: Sendable {
    /// The commits that changed the item at `path`, newest first, in parts as git finds
    /// them. A file's history follows its renames; a folder's is that of what it holds.
    /// Ending the iteration stops git.
    ///
    /// The stream throws `FileSystemError` when git cannot read the history.
    func history(of path: String, isFolder: Bool, in repository: GitRepository)
        -> AsyncThrowingStream<[GitCommit], any Error>

    /// The changes `commit` made to the item at `path`, against its first parent; a
    /// renamed file's under both its names.
    ///
    /// - Parameter limit: the most bytes of git's output to read, `nil` for all; a diff
    ///   cut short is not `isComplete`.
    /// - Throws: `FileSystemError` when git cannot read them.
    func changes(
        of path: String, in commit: GitCommit, repository: GitRepository, limit: Int?
    ) async throws -> GitDiff

    /// What the item at `path` holds on disk against the last commit, staged or not.
    ///
    /// - Parameter limit: as for `changes(of:in:repository:limit:)`.
    /// - Throws: `FileSystemError` when git cannot read them.
    func uncommittedChanges(of path: String, in repository: GitRepository, limit: Int?)
        async throws -> GitDiff
}
