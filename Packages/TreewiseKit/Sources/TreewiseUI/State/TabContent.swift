import TreewiseCore

/// What one tab shows: the items of its folder and the user's view of them.
public struct TabContent: Sendable, Equatable {
    /// The folder itself, for the tab's title and the path bar.
    public internal(set) var folder: FileItem?
    /// The folder's items, in no particular order; `BrowserState.visibleItems`
    /// sorts and filters them.
    public internal(set) var items: [FileItem] = []
    /// The selected items.
    public internal(set) var selection: Set<FileItem.ID> = []
    /// The search text for the current folder; empty shows everything.
    public internal(set) var query = ""
    /// Why the folder could not be read, if it could not.
    public internal(set) var failure: FileSystemError?
    /// The free space on the folder's volume, for the status bar.
    public internal(set) var availableCapacity: Int64?
    /// The folder's containers, nearest first, for Enclosing Folder and for
    /// finding a folder left when this one is deleted.
    var ancestry: [FileItem.ID] = []
}
