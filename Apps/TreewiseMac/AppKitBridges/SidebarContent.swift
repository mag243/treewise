import AppKit
import TreewiseCore

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
    var select: (FileItem) -> Void
    /// Ejects volumes (ADR 0044).
    var eject: ([FileItem]) -> Void
    var drop: DropAction
    /// Adds, removes and moves favorites (ADR 0050).
    var favoriteActions: SidebarFavoriteActions
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
