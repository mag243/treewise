/// The folders items were last moved or copied into, by any way, for Move to and Copy to
/// (ADR 0147): the newest first, each once, at most `limit`.
///
/// Invariant: `folders` holds no folder twice and at most `limit` folders.
public struct RecentTargets: Equatable, Sendable {
    /// How many folders are kept.
    public static let limit = 5

    /// The folders, the newest first.
    public private(set) var folders: [FileItem.ID]

    /// Creates the list from folders kept before, keeping the first of any duplicates and
    /// at most `limit`.
    public init(folders: [FileItem.ID] = []) {
        var seen: Set<FileItem.ID> = []
        self.folders = Array(folders.filter { seen.insert($0).inserted }.prefix(Self.limit))
    }

    /// Records a transfer into `target` of items from the folders `sources`. A transfer of
    /// no items, or of items only from `target` itself, as a copy beside itself, is no
    /// target.
    public mutating func record(target: FileItem.ID, sources: [FileItem.ID]) {
        guard sources.contains(where: { $0 != target }) else { return }
        folders.removeAll { $0 == target }
        folders.insert(target, at: 0)
        if folders.count > Self.limit { folders.removeLast(folders.count - Self.limit) }
    }
}
