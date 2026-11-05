/// The Favorites the user chose, in the order the sidebar shows them
/// (ADR 0050). Whether a folder exists is not its concern: a folder that is
/// missing stays in the list and its row comes back when the folder does.
///
/// Invariant: a folder is in the list at most once.
public struct FavoriteList: Equatable, Sendable {
    /// The folders, in order.
    public private(set) var folders: [FileItem.ID]

    /// Creates a list from stored folders, keeping the first of any duplicates.
    public init(folders: [FileItem.ID]) {
        var seen = Set<FileItem.ID>()
        self.folders = folders.filter { seen.insert($0).inserted }
    }

    /// Adds a folder before `next`, or at the end when `next` is `nil` or not
    /// in the list. A folder already in the list stays where it is.
    public mutating func add(_ folder: FileItem.ID, before next: FileItem.ID? = nil) {
        guard !folders.contains(folder) else { return }
        folders.insert(folder, at: index(of: next))
    }

    /// Removes a folder from the list; the folder itself is not touched.
    public mutating func remove(_ folder: FileItem.ID) {
        folders.removeAll { $0 == folder }
    }

    /// Moves a folder of the list before `next`, or to the end when `next` is
    /// `nil` or not in the list.
    public mutating func move(_ folder: FileItem.ID, before next: FileItem.ID?) {
        guard folders.contains(folder), folder != next else { return }
        remove(folder)
        folders.insert(folder, at: index(of: next))
    }

    /// Follows a folder that was renamed or moved, and the folders inside it:
    /// an identity below another starts with it and a slash (ADR 0015).
    public mutating func relocate(_ old: FileItem.ID, to new: FileItem.ID) {
        let prefix = old.rawValue + "/"
        folders = folders.map { folder in
            if folder == old { return new }
            guard folder.rawValue.hasPrefix(prefix) else { return folder }
            return FileItem.ID(new.rawValue + "/" + folder.rawValue.dropFirst(prefix.count))
        }
    }

    private func index(of next: FileItem.ID?) -> Int {
        next.flatMap(folders.firstIndex(of:)) ?? folders.count
    }
}
