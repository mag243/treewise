import AppKit
import TreewiseCore

/// What the sidebar can do with the Favorites (ADR 0050).
struct SidebarFavoriteActions {
    /// Adds a folder before a favorite, or at the end.
    var add: (FileItem.ID, FileItem.ID?) -> Void
    var remove: (FileItem.ID) -> Void
    /// Moves a favorite before another, or to the end.
    var move: (FileItem.ID, FileItem.ID?) -> Void
    var restore: () -> Void
    var isFavorite: (FileItem.ID) -> Bool
}

/// The Favorites in the sidebar: the rows' context menus, and dragging: a
/// folder dropped between the rows is added, a favorite dragged among them is
/// moved (ADR 0050). A drop on a favorite's row goes into that folder as ever,
/// except for a favorite, which cannot leave the list.
extension SidebarCoordinator {
    /// The type a dragged favorite carries: no file URL, so it cannot land
    /// anywhere that would move the folder itself.
    static let favoriteDragType = NSPasteboard.PasteboardType("me.m-domain.treewise.favorite")

    private var favoritesRoot: SidebarNode? { roots.first }

    /// Whether the row is a favorite, not a folder of the tree.
    func isFavoriteRow(_ node: SidebarNode, in outline: NSOutlineView) -> Bool {
        outline.parent(forItem: node) as? SidebarNode === favoritesRoot
    }

    /// The context menu of a row, or `nil` for a row without one.
    func menu(for node: SidebarNode, in outline: NSOutlineView) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if node === favoritesRoot {
            menu.addItem(restoreItem())
        } else if let item = node.item, item.id != .computer {
            if isFavoriteRow(node, in: outline) {
                menu.addItem(
                    ClosureMenuItem(
                        String(localized: "Remove from Favorites"), symbol: "star.slash"
                    ) { [weak self] in
                        self?.favoriteActions?.remove(item.id)
                    })
                menu.addItem(restoreItem())
            } else {
                menu.addItem(
                    ClosureMenuItem(
                        String(localized: "Add to Favorites"), symbol: "star",
                        enabled: favoriteActions?.isFavorite(item.id) == false
                    ) { [weak self] in
                        self?.favoriteActions?.add(item.id, nil)
                    })
            }
            if item.isEjectable, let eject {
                menu.addItem(.separator())
                menu.addItem(
                    ClosureMenuItem(String(localized: "Eject"), symbol: "eject") { eject([item]) })
            }
        }
        return menu.items.isEmpty ? nil : menu
    }

    private func restoreItem() -> NSMenuItem {
        ClosureMenuItem(
            String(localized: "Restore Default Favorites"), symbol: "arrow.counterclockwise"
        ) { [weak self] in
            self?.favoriteActions?.restore()
        }
    }

    /// The operation of a drag over Favorites, retargeting the outline to the
    /// place between rows; `nil` when the drag is not about the list.
    func validateFavoriteDrop(
        _ info: any NSDraggingInfo, in outline: NSOutlineView, item: Any?, index: Int
    ) -> NSDragOperation? {
        guard let root = favoritesRoot else { return nil }
        let node = item as? SidebarNode
        let isFavoriteDrag =
            info.draggingPasteboard.availableType(from: [Self.favoriteDragType]) != nil
        let count = root.children?.count ?? 0
        let place: Int
        if node === root {
            place = index == NSOutlineViewDropOnItemIndex ? count : index
        } else if node == nil, index <= 1 {
            // Above Favorites, or between its last row and Locations.
            place = index == 0 ? 0 : count
        } else if isFavoriteDrag, let node, isFavoriteRow(node, in: outline) {
            place = root.children?.firstIndex { $0 === node } ?? count
        } else {
            return isFavoriteDrag ? [] : nil
        }
        guard isFavoriteDrag || Self.holdsOnlyFolders(info.draggingPasteboard) else {
            return []
        }
        outline.setDropItem(root, dropChildIndex: place)
        DropRouting.finish()
        return isFavoriteDrag ? .move : .link
    }

    /// Performs a drop on Favorites at `index`; false when the drop is not one.
    func acceptFavoriteDrop(_ info: any NSDraggingInfo, item: Any?, index: Int) -> Bool {
        guard let root = favoritesRoot, item as? SidebarNode === root,
            index != NSOutlineViewDropOnItemIndex
        else { return false }
        let children = root.children ?? []
        let next = children.indices.contains(index) ? children[index].item?.id : nil
        let pasteboard = info.draggingPasteboard
        if let dragged = pasteboard.string(forType: Self.favoriteDragType) {
            favoriteActions?.move(FileItem.ID(dragged), next)
        } else {
            for url in FilePasteboard.fileURLs(on: pasteboard) {
                favoriteActions?.add(FileItem.ID(url.standardizedFileURL.path), next)
            }
        }
        return true
    }

    private static func holdsOnlyFolders(_ pasteboard: NSPasteboard) -> Bool {
        let urls = FilePasteboard.fileURLs(on: pasteboard)
        return !urls.isEmpty
            && urls.allSatisfy { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                return values?.isDirectory == true && values?.isPackage != true
            }
    }
}
