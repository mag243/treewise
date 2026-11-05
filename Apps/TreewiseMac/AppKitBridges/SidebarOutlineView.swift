import AppKit
import SwiftUI
import TreewiseCore

/// The sidebar as an `NSOutlineView` (ADR 0002): Favorites as a flat list,
/// Locations as a tree whose folders load their subfolders when expanded.
struct SidebarOutlineView: NSViewRepresentable {
    var favorites: [FileItem]
    var locations: [FileItem]
    /// The folder the active pane shows; its row is selected when visible.
    var currentFolder: FileItem.ID
    /// Whether folders list their hidden subfolders (ADR 0023).
    var showsHiddenFiles: Bool
    var loadSubfolders: (FileItem.ID) async -> [FileItem]
    var select: (FileItem) -> Void
    /// Ejects volumes (ADR 0044).
    var eject: ([FileItem]) -> Void
    var drop: DropAction
    /// Adds, removes and moves favorites (ADR 0050).
    var favoriteActions: SidebarFavoriteActions

    func makeCoordinator() -> SidebarCoordinator {
        SidebarCoordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let outline = SidebarOutline()
        context.coordinator.attach(to: outline)
        let scrollView = NSScrollView()
        scrollView.documentView = outline
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(with: self)
    }
}
