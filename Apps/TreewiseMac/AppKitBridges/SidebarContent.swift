import AppKit
import TreewiseCore
import TreewiseUI

/// What the sidebar shows, as an `NSOutlineView` (ADR 0002): Favorites as a
/// flat list, Locations as a tree whose folders load their subfolders when
/// expanded. The sidebar hands it to the outline's coordinator on every change.
struct SidebarContent {
    var favorites: [FileItem]
    var locations: [FileItem]
    /// The folder the active pane shows; its row is selected when visible.
    var currentFolder: FileItem.ID
    /// The way through the tree to open down to, farthest out first.
    var pathToReveal: [FileItem.ID]?
    /// Whether folders list their hidden subfolders (ADR 0023).
    var showsHiddenFiles: Bool
    var loadSubfolders: (FileItem.ID) async -> [FileItem]
    /// Whether a folder has subfolders, so a row without them shows no disclosure
    /// triangle; unknown where looking costs too much (ADR 0108).
    var subfolderPresence: (FileItem.ID) async -> SubfolderPresence
    /// The changes to a folder's entries, for following the folders open in the tree
    /// (ADR 0112).
    var changes: (FileItem.ID) -> AsyncStream<Void>
    /// The folder the active pane shows and what it holds, so the tree reads that folder
    /// again when its listing changes (ADR 0112).
    var shownListing: SidebarShownListing
    var select: (FileItem) -> Void
    /// Ejects volumes (ADR 0044).
    var eject: ([FileItem]) -> Void
    var drop: DropAction
    /// Adds, removes and moves favorites (ADR 0050).
    var favoriteActions: SidebarFavoriteActions
}

/// The folder a pane shows and the items in it, by id.
struct SidebarShownListing: Equatable {
    var folder: FileItem.ID
    var items: [FileItem.ID]
}

extension SidebarCoordinator {
    /// A new outline fed by this coordinator, in a scroll view.
    func makeScrollView() -> NSScrollView {
        let outline = SidebarOutline()
        attach(to: outline)
        let scrollView = NSScrollView()
        scrollView.documentView = outline
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        return scrollView
    }
}
