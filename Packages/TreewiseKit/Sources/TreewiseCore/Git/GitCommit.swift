import Foundation

/// A commit in an item's history (ADR 0153): who made it, when and why, and the item's
/// path in it.
///
/// Paths are relative to the repository's top folder, as git writes them.
public struct GitCommit: Hashable, Sendable, Identifiable {
    /// The characters of a short hash, as git shows one by default.
    private static let shortHashLength = 7

    /// The full hash.
    public let id: String
    /// The hashes of its parents: none for a first commit, two or more for a merge.
    public let parents: [String]
    /// The author's name.
    public let author: String
    /// The author's e-mail address.
    public let email: String
    /// When the author made it.
    public let date: Date
    /// The whole message, without the newlines git ends it with.
    public let message: String
    /// The item's path in this commit; `nil` where the commit has no change of its own to
    /// it, as a merge, or where the history is a folder's.
    public let path: String?
    /// The path the item had before this commit renamed it; `nil` without a rename.
    public let renamedFrom: String?

    /// Creates a commit.
    public init(
        id: String, parents: [String], author: String, email: String, date: Date,
        message: String, path: String?, renamedFrom: String?
    ) {
        self.id = id
        self.parents = parents
        self.author = author
        self.email = email
        self.date = date
        self.message = message
        self.path = path
        self.renamedFrom = renamedFrom
    }

    /// The hash as git abbreviates it by default.
    public var shortHash: String { String(id.prefix(Self.shortHashLength)) }

    /// The message's first line.
    public var subject: String {
        String(message.prefix { $0 != "\n" })
    }
}
