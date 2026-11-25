/// A git repository's state at one moment: where its HEAD is, how far its branch is from
/// its upstream, and which items differ from the last commit (ADR 0149).
///
/// Paths are relative to the repository's top folder, with `/` between the names, as git
/// writes them. They are compared as the file system compares names, so a name written
/// decomposed on disk finds git's precomposed one.
public struct GitRepositoryStatus: Hashable, Sendable {
    /// Where HEAD points.
    public enum Head: Hashable, Sendable {
        /// On a branch, by its name.
        case branch(String)
        /// On a commit with no branch, by its short hash.
        case detached(String)
    }

    /// The branch on a remote a branch follows.
    public enum Upstream: Hashable, Sendable {
        /// It is there: `ahead` commits on the branch it lacks, `behind` commits on it
        /// the branch lacks.
        case following(ahead: Int, behind: Int)
        /// It was deleted from the remote.
        case gone
    }

    /// Where HEAD points; `nil` when git did not say.
    public var head: Head?
    /// The branch on a remote that HEAD's branch follows; `nil` when it follows none.
    public var upstream: Upstream?

    /// Each listed item's state, by its key.
    var items: [String: GitItemState] = [:]
    /// The folders git lists whole, untracked or ignored, by their key: what they hold
    /// shares their state.
    var wholeFolders: [String: GitItemState] = [:]
    /// The folders that hold a change, by their key; the top folder's key is empty.
    var changedFolders: Set<String> = []
    /// The folders that hold an item in conflict, by their key.
    var conflictFolders: Set<String> = []

    /// A repository with no state yet.
    public init() {}

    /// Whether anything in the repository differs from the last commit, ignored items aside.
    public var hasChanges: Bool { changedFolders.contains("") }

    /// The state of the item at `path`, relative to the top folder; `nil` when it is
    /// unchanged. A folder that holds an item in conflict is in conflict, so the tree leads
    /// to it first; one that holds another change is modified.
    public func state(of path: String) -> GitItemState? {
        let key = Self.key(path)
        if let state = items[key] ?? wholeFolders[key] { return state }
        var folder = Substring(key)
        while let slash = folder.lastIndex(of: "/") {
            folder = folder[..<slash]
            if let state = wholeFolders[String(folder)] { return state }
        }
        if conflictFolders.contains(key) { return .conflict }
        return changedFolders.contains(key) ? .modified : nil
    }

    /// Records the state of an item git listed; `isFolder` for a folder it lists whole.
    mutating func mark(_ state: GitItemState?, at path: String, isFolder: Bool = false) {
        let key = Self.key(path)
        if let state {
            if isFolder { wholeFolders[key] = state } else { items[key] = state }
        }
        guard state != .ignored else { return }
        var folder = Substring(key)
        changedFolders.insert("")
        if state == .conflict { conflictFolders.insert("") }
        while let slash = folder.lastIndex(of: "/") {
            folder = folder[..<slash]
            changedFolders.insert(String(folder))
            if state == .conflict { conflictFolders.insert(String(folder)) }
        }
    }

    /// The form a path is compared in: as the file system compares names.
    static func key(_ path: String) -> String {
        ConflictResolver.comparisonKey(path)
    }
}
