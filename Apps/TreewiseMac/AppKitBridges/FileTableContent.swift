import AppKit
import TreewiseCore
import TreewiseUI

/// What the list reports back to its pane.
struct FileTableActions {
    var select: (Set<FileItem.ID>) -> Void
    /// Opens an item; the modifiers held decide where (ADR 0022).
    var open: (FileItem, _ command: Bool, _ option: Bool) -> Void
    var sort: (SortColumn) -> Void
    /// Shows or hides a column, chosen from the headers' menu (ADR 0127).
    var toggleColumn: (FolderColumn) -> Void
    var focus: () -> Void
    var cut: () -> Void
    var copy: () -> Void
    var paste: () -> Void
    var canPaste: () -> Bool
    var rename: (FileItem, String) -> Void
    /// The list started the rename it was asked for; says whether that rename asks for
    /// proposals at once, as Rename with Suggestions does (ADR 0066).
    var renameStarted: () -> Bool
    /// Tells the window the view brought the item it asked for into view.
    var revealed: () -> Void
    /// Asks for proposals for the item being renamed in this field (ADR 0066).
    var suggestName: (FileItem, NSTextField) -> Void
    /// Whether a name being typed shows its misspelled words (ADR 0084).
    var checksSpelling: () -> Bool
    /// The context menu for the given items, or for the folder when empty.
    var contextMenu: ([FileItem]) -> NSMenu
    var drop: DropAction
    /// The files to preview for items, also copies of entries of an archive.
    var previewURLs: ([FileItem]) async -> [URL]
    /// What goes on a drag for an entry of an archive (ADR 0076).
    var archiveDrag: (FileItem) -> any NSPasteboardWriting
}

/// What a pane's list shows: an `NSTableView` with Name, Date Modified, Size
/// and Kind, sortable by its headers (ADR 0002), which shows `items` in the
/// order given. Its pane hands it to the list's coordinator on every change.
struct FileTableContent {
    /// The folder the list shows: the target of a drop on a file or on empty space.
    var folder: FileItem?
    var items: [FileItem]
    var selection: Set<FileItem.ID>
    var sort: ItemSort
    /// Which columns beside the name show (ADR 0127).
    var columns: TableColumnLayout
    var isActive: Bool
    /// Items cut to the clipboard, shown dimmed.
    var cutItems: Set<FileItem.ID>
    /// An item to start renaming, such as a new folder.
    var renameRequest: FileItem.ID?
    /// An item to bring into view, such as a new archive.
    var revealRequest: FileItem.ID?
    /// The downloads running, with their fractions done (ADR 0051).
    var downloads: [FileItem.ID: Double] = [:]
    /// The items' states in their git repository, the unchanged left out (ADR 0149).
    var gitStates: [FileItem.ID: GitItemState] = [:]
    /// Whether names show their extension (ADR 0023).
    var showsExtensions: Bool
    /// The height of the rows, from the row density setting.
    var rowHeight: CGFloat
    var actions: FileTableActions
}

extension FileTableCoordinator {
    /// A new view fed by this coordinator, in a scroll view; a click anywhere
    /// in it makes the pane active.
    func makeScrollView() -> NSScrollView {
        let table = PaneTableView()
        attach(to: table)
        let scrollView = NSScrollView()
        scrollView.documentView = table
        clickFocus = PaneClickFocus(focusing: table, in: scrollView) { [weak self] in
            self?.actions?.focus()
        }
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }
}
