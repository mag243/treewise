import AppKit
import TreewiseCore
import TreewiseUI

/// The icon view's layout: rows of tiles. It shows no gap between tiles
/// while dragging, because a drop between tiles lands in the folder, not at
/// a place in its order.
final class FileGridLayout: NSCollectionViewFlowLayout {
    private static let spacing: CGFloat = 4
    private static let inset: CGFloat = 12

    override init() {
        super.init()
        itemSize = FileGridItem.tileSize
        minimumInteritemSpacing = Self.spacing
        minimumLineSpacing = Self.spacing
        sectionInset = NSEdgeInsets(
            top: Self.inset, left: Self.inset, bottom: Self.inset, right: Self.inset)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FileGridLayout is made in code only")
    }

    override func layoutAttributesForInterItemGap(before indexPath: IndexPath)
        -> NSCollectionViewLayoutAttributes?
    {
        nil
    }
}

/// Feeds the icon view and turns its events into `FileTableActions`, as the
/// list's coordinator does (ADR 0025).
@MainActor
final class FileGridCoordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    /// The screen scale to make thumbnails for before the view is in a window.
    private static let defaultScale: CGFloat = 2

    weak var grid: PaneCollectionView?
    var items: [FileItem] = []
    var actions: FileTableActions?
    /// Makes the pane active on a click anywhere in its scroll view.
    var clickFocus: PaneClickFocus?
    var folder: FileItem?
    /// The item whose name is being edited, if any.
    var renaming: FileItem?
    private var showsExtensions = true
    private var cutItems: Set<FileItem.ID> = []
    private var downloads: [FileItem.ID: Double] = [:]
    private var isActive = true
    /// Set while the view is brought in line with the state, so its own
    /// selection changes are not sent back as user actions.
    private var isApplyingState = false

    func attach(to grid: PaneCollectionView) {
        self.grid = grid
        grid.collectionViewLayout = FileGridLayout()
        grid.isSelectable = true
        grid.allowsMultipleSelection = true
        grid.backgroundColors = [.controlBackgroundColor]
        grid.register(FileGridItem.self, forItemWithIdentifier: FileGridItem.identifier)
        grid.dataSource = self
        grid.delegate = self
        grid.registerForDraggedTypes(DropRouting.pasteboardTypes)
        grid.setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: true)
        grid.setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: false)
        grid.onFocus = { [weak self] in self?.actions?.focus() }
        grid.onOpen = { [weak self] index in self?.open(index) }
        grid.onSelect = { [weak self] in self?.selectionChanged() }
        grid.commands = TableCommands(
            cut: { [weak self] in self?.actions?.cut() },
            copy: { [weak self] in self?.actions?.copy() },
            paste: { [weak self] in self?.actions?.paste() },
            rename: { [weak self] index in self?.beginRename(index: index) },
            canPaste: { [weak self] in self?.actions?.canPaste() ?? false },
            menu: { [weak self] index in self?.contextMenu(index: index) },
            selectedURLs: { [weak self] in await self?.selectedURLs() ?? [] })
    }

    func update(with view: FileGridView) {
        guard let grid else { return }
        actions = view.actions
        folder = view.folder
        isApplyingState = true
        defer { isApplyingState = false }
        if items != view.items || cutItems != view.cutItems
            || showsExtensions != view.showsExtensions || isActive != view.isActive
        {
            items = view.items
            cutItems = view.cutItems
            showsExtensions = view.showsExtensions
            isActive = view.isActive
            grid.reloadData()
        }
        if downloads != view.downloads {
            downloads = view.downloads
            for (index, item) in items.enumerated() {
                let tile = grid.item(at: IndexPath(item: index, section: 0)) as? FileGridItem
                tile?.showCloudStatus(isOnlyOnline: item.isOnlyOnline, download: downloads[item.id])
            }
        }
        let selected = Set(
            items.indices.filter { view.selection.contains(items[$0].id) }
                .map { IndexPath(item: $0, section: 0) })
        if grid.selectionIndexPaths != selected { grid.selectionIndexPaths = selected }
        if view.isActive { DispatchQueue.main.async { PaneFocus.follow(grid) } }
        if let request = view.revealRequest,
            let index = items.firstIndex(where: { $0.id == request })
        {
            view.actions.revealed()
            DispatchQueue.main.async { [weak self] in self?.reveal(index: index) }
        }
        if let request = view.renameRequest,
            let index = items.firstIndex(where: { $0.id == request })
        {
            let suggests = view.actions.renameStarted()
            DispatchQueue.main.async { [weak self] in
                self?.beginRename(index: index, suggests: suggests)
            }
        }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int)
        -> Int
    {
        items.count
    }

    func collectionView(
        _ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let made = collectionView.makeItem(withIdentifier: FileGridItem.identifier, for: indexPath)
        guard let tile = made as? FileGridItem, items.indices.contains(indexPath.item) else {
            return made
        }
        let item = items[indexPath.item]
        tile.show(
            item, name: shownName(of: item), icon: icon(of: item, for: tile),
            isCut: cutItems.contains(item.id))
        tile.isActivePane = isActive
        tile.showCloudStatus(isOnlyOnline: item.isOnlyOnline, download: downloads[item.id])
        return tile
    }

    func collectionView(
        _ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        selectionChanged()
    }

    func collectionView(
        _ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>
    ) {
        selectionChanged()
    }

    /// The name a tile shows: without its extension when the setting hides them.
    func shownName(of item: FileItem) -> String {
        DisplayName.text(for: item, showsExtension: showsExtensions)
    }

    /// The cached thumbnail, or the workspace icon while a thumbnail is made.
    /// A file kept only online gets no thumbnail, which could download it (ADR 0051).
    private func icon(of item: FileItem, for tile: FileGridItem) -> NSImage {
        let icon = ItemIcon.image(for: item)
        icon.size = FileGridItem.iconSize
        guard !item.isOnlyOnline else { return icon }
        if let thumbnail = ThumbnailCache.shared.cached(item) { return thumbnail }
        let scale = grid?.window?.backingScaleFactor ?? Self.defaultScale
        ThumbnailCache.shared.make(item, size: FileGridItem.iconSize, scale: scale) { [weak tile] in
            tile?.showThumbnail($0, of: item.id)
        }
        return icon
    }

    private func selectionChanged() {
        guard !isApplyingState, let grid else { return }
        let ids = grid.selectionIndexPaths.compactMap {
            items.indices.contains($0.item) ? items[$0.item].id : nil
        }
        actions?.select(Set(ids))
        QuickLookSource.shared.follow { [weak self] in await self?.selectedURLs() ?? [] }
    }

    private func selectedURLs() async -> [URL] {
        let chosen = (grid?.selectionIndexPaths ?? []).sorted().compactMap {
            items.indices.contains($0.item) ? items[$0.item] : nil
        }
        return await actions?.previewURLs(chosen) ?? []
    }

    private func open(_ index: Int) {
        guard items.indices.contains(index) else { return }
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        actions?.open(items[index], flags.contains(.command), flags.contains(.option))
    }

    /// The context menu for the selection, or for the folder without one.
    private func contextMenu(index: Int?) -> NSMenu? {
        let paths = index == nil ? [] : (grid?.selectionIndexPaths ?? []).sorted()
        return actions?.contextMenu(
            paths.compactMap { items.indices.contains($0.item) ? items[$0.item] : nil })
    }
}
