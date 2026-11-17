import TreewiseCore

/// What one tab shows: the items of its folder and the user's view of them.
public struct TabContent: Sendable, Equatable {
    /// The folder this content was read from, with its items or its failure; another
    /// than the tab's while the tab still reads the folder it opened (ADR 0121).
    public internal(set) var readFolder: FileItem.ID?
    /// Whether the folder the tab opened has been read for longer than
    /// `BrowserState.readingNoticeDelay`, so the tab says it is reading (ADR 0121).
    var isReadingNoticed = false
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
