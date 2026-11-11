import AppKit
import TreewiseCore

/// What a pane's icon view shows: an `NSCollectionView` of tiles (ADR 0025),
/// with the same actions as the list, which shows `items` in the order given.
/// Its pane hands it to the view's coordinator on every change.
struct FileGridContent {
    /// The folder the view shows: the target of a drop beside the tiles.
    var folder: FileItem?
    var items: [FileItem]
    var selection: Set<FileItem.ID>
    var isActive: Bool
    /// Items cut to the clipboard, shown dimmed.
    var cutItems: Set<FileItem.ID>
    /// An item to start renaming, such as a new folder.
    var renameRequest: FileItem.ID?
    /// An item to bring into view, such as a new archive.
    var revealRequest: FileItem.ID?
    /// The downloads running, with their fractions done (ADR 0051).
    var downloads: [FileItem.ID: Double] = [:]
    /// Whether names show their extension (ADR 0023).
    var showsExtensions: Bool
    var actions: FileTableActions
}

extension FileGridCoordinator {
    /// A new view fed by this coordinator, in a scroll view; a click anywhere
    /// in it makes the pane active.
    func makeScrollView() -> NSScrollView {
        let grid = PaneCollectionView()
        attach(to: grid)
        let scrollView = NSScrollView()
        scrollView.documentView = grid
        clickFocus = PaneClickFocus(focusing: grid, in: scrollView) { [weak self] in
            self?.actions?.focus()
        }
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }
}
