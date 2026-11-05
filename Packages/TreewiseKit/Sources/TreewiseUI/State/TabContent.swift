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

/// Where a folder opens (ADR 0022).
public enum OpenPlacement: Sendable, Equatable {
    /// In the pane it was opened from.
    case samePane
    /// In the other pane of a split; in the same pane without a split.
    case otherPane
    /// In a new tab of the pane it was opened from.
    case newTab

    /// Where a double-click or ⌘↓ opens a folder: ⌘ in a new tab, ⌥ opposite
    /// the setting's `preferred` pane, otherwise in that pane.
    public static func forOpening(command: Bool, option: Bool, preferred: OpenPlacement)
        -> OpenPlacement
    {
        if command { return .newTab }
        guard option else { return preferred }
        return preferred == .otherPane ? .samePane : .otherPane
    }
}

/// What closing the active tab closed (ADR 0022).
public enum TabClosing: Sendable, Equatable {
    /// The tab; its pane has others.
    case tab
    /// The pane of a split, with its last tab.
    case pane
    /// Nothing: it is the window's last tab, so the window closes.
    case window
}

/// What opening an item did.
public enum OpenResult: Sendable, Equatable {
    /// A folder opened in the browser.
    case navigated
    /// A file, which the app opens in its default application.
    case openFile(FileItem)
}
