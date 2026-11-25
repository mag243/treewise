/// A git repository's working copy, as a reader found it (ADR 0149).
public struct GitRepository: Hashable, Sendable {
    /// The working copy's top folder, in the terms of the folder it was found from.
    public let top: FileItem.ID
    /// Where its git data is: `.git` in the top folder, or elsewhere for a worktree.
    public let gitDirectory: String

    /// Creates a repository.
    public init(top: FileItem.ID, gitDirectory: String) {
        self.top = top
        self.gitDirectory = gitDirectory
    }
}

/// Reads git repositories' state without changing them (ADR 0149).
public protocol GitStatusReading: Sendable {
    /// Whether a git is installed that can run without asking to install one.
    var hasGit: Bool { get }

    /// The repository whose working copy holds `folder`; `nil` outside one, inside its
    /// git data, or without git.
    func repository(holding folder: FileItem.ID) async -> GitRepository?

    /// The repository's state now.
    ///
    /// - Throws: `FileSystemError` when git cannot read it.
    func status(of repository: GitRepository) async throws -> GitRepositoryStatus

    /// A stream that yields the paths, from the top folder, of a batch of changes that may
    /// change the repository's state: a file in its working copy, or its HEAD, index or
    /// branches, which come as the top folder's empty path. Ending the iteration stops it.
    func changes(of repository: GitRepository) -> AsyncStream<[String]>

    /// The path of `item` from the repository's top folder, as `GitRepositoryStatus`
    /// takes it; empty for the top folder, `nil` for an item outside it.
    func relativePath(of item: FileItem.ID, in repository: GitRepository) -> String?

    /// Whether `folder` is the top folder of a working copy, found without running git,
    /// so the sidebar can mark it.
    func isRepositoryTop(_ folder: FileItem.ID) -> Bool
}
