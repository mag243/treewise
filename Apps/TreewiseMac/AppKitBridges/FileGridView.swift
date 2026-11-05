import AppKit
import SwiftUI
import TreewiseCore

/// A pane's icon view: an `NSCollectionView` of tiles (ADR 0025), with the
/// same actions as the list. It shows `items` in the order given.
struct FileGridView: NSViewRepresentable {
    /// The folder the view shows: the target of a drop beside the tiles.
    var folder: FileItem?
    var items: [FileItem]
    var selection: Set<FileItem.ID>
    var isActive: Bool
    /// Items cut to the clipboard, shown dimmed.
    var cutItems: Set<FileItem.ID>
    /// An item to start renaming, such as a new folder.
    var renameRequest: FileItem.ID?
    /// The downloads running, with their fractions done (ADR 0051).
    var downloads: [FileItem.ID: Double] = [:]
    /// Whether names show their extension (ADR 0023).
    var showsExtensions: Bool
    var actions: FileTableActions

    func makeCoordinator() -> FileGridCoordinator {
        FileGridCoordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let grid = PaneCollectionView()
        context.coordinator.attach(to: grid)
        let scrollView = NSScrollView()
        scrollView.documentView = grid
        let coordinator = context.coordinator
        let focus: () -> Void = { [weak coordinator] in coordinator?.actions?.focus() }
        coordinator.clickFocus = PaneClickFocus(focusing: grid, in: scrollView, onClick: focus)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(with: self)
    }
}
