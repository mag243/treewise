import SwiftUI
import TreewiseCore
import TreewiseUI
import UIKit
import UniformTypeIdentifiers

/// The table's rows as a UIKit collection view (ADR 0116): a tap opens a folder or shows a
/// file in Quick Look, a long press shows the context menu, a row is dragged as its item,
/// and a drop on a folder's row, or on a file's row or beside the rows for the folder shown,
/// goes through the drag rules (ADR 0047).
struct FolderCollection: UIViewRepresentable {
    let browser: BrowserState
    /// The app's one undo history, which the system's Undo, ⌘Z and the three-finger swipe
    /// use while the table is the first responder (ADR 0047).
    let undoManager: UndoManager
    /// Whether the rows are a narrow folder's: the name with the date and size beneath it.
    let isNarrow: Bool
    let items: [FileItem]
    let folder: FileItem?
    let settings: BrowserSettings
    let actions: ItemActions
    let drops: ItemDrops

    func makeCoordinator() -> FolderCollectionCoordinator {
        FolderCollectionCoordinator()
    }

    func makeUIView(context: Context) -> UICollectionView {
        var list = UICollectionLayoutListConfiguration(appearance: .plain)
        list.showsSeparators = true
        let view = FolderCollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewCompositionalLayout.list(using: list))
        view.sharedUndo = undoManager
        view.accessibilityIdentifier = "folderTable"
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: UICollectionView, context: Context) {
        context.coordinator.update(with: self, in: view)
    }
}

/// Feeds the table's collection view and turns its events into `BrowserState`'s.
@MainActor
final class FolderCollectionCoordinator: NSObject, UICollectionViewDelegate {
    private(set) var content: FolderCollection?
    private var dataSource: UICollectionViewDiffableDataSource<Int, FileItem.ID>?
    private var itemsByID: [FileItem.ID: FileItem] = [:]
    /// Set while the view follows the state, so its own selection is not sent back.
    private var isApplyingState = false

    func attach(to view: UICollectionView) {
        typealias Registration = UICollectionView.CellRegistration<
            UICollectionViewListCell, FileItem.ID
        >
        let registration = Registration { [weak self] cell, _, id in
            self?.configure(cell, for: id)
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: view) { view, path, id in
            view.dequeueConfiguredReusableCell(using: registration, for: path, item: id)
        }
        view.delegate = self
        view.dragDelegate = self
        view.dropDelegate = self
        view.dragInteractionEnabled = true
        view.allowsMultipleSelection = true
    }

    private func configure(_ cell: UICollectionViewListCell, for id: FileItem.ID) {
        guard let item = itemsByID[id] else { return }
        let showsExtensions = content?.settings.showsExtensions ?? true
        if content?.isNarrow == true {
            cell.contentConfiguration = UIHostingConfiguration {
                FolderNarrowRow(item: item, showsExtensions: showsExtensions)
            }
        } else {
            cell.contentConfiguration = UIHostingConfiguration {
                FolderTableRow(item: item, showsExtensions: showsExtensions)
            }
            .margins(.horizontal, FolderTableColumn.margin)
        }
    }

    func update(with content: FolderCollection, in view: UICollectionView) {
        let isFirst = self.content == nil
        self.content = content
        itemsByID = Dictionary(content.items.map { ($0.id, $0) }) { first, _ in first }
        var snapshot = NSDiffableDataSourceSnapshot<Int, FileItem.ID>()
        snapshot.appendSections([0])
        snapshot.appendItems(content.items.map(\.id))
        // An item may change under the same identity, as when it is renamed or its size
        // changes, and every row changes when the folder turns narrow or wide.
        let shown = Set(dataSource?.snapshot().itemIdentifiers ?? [])
        snapshot.reconfigureItems(content.items.map(\.id).filter(shown.contains))
        dataSource?.apply(snapshot, animatingDifferences: !isFirst)
        showSelection(of: content, in: view)
    }

    private func showSelection(of content: FolderCollection, in view: UICollectionView) {
        let tab = content.browser.layout.focusedPane.activeTabID
        let selected = content.browser.content(of: tab).selection
        isApplyingState = true
        defer { isApplyingState = false }
        for (index, item) in content.items.enumerated() {
            let path = IndexPath(item: index, section: 0)
            let isSelected = view.indexPathsForSelectedItems?.contains(path) ?? false
            if selected.contains(item.id), !isSelected {
                view.selectItem(at: path, animated: false, scrollPosition: [])
            } else if !selected.contains(item.id), isSelected {
                view.deselectItem(at: path, animated: false)
            }
        }
    }

    /// The item of a row.
    func item(at path: IndexPath?) -> FileItem? {
        guard let path, let id = dataSource?.itemIdentifier(for: path) else { return nil }
        return itemsByID[id]
    }

    // MARK: - Selection, open, menu

    func collectionView(_ view: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectionChanged(in: view)
    }

    func collectionView(_ view: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        selectionChanged(in: view)
    }

    private func selectionChanged(in view: UICollectionView) {
        guard !isApplyingState, let browser = content?.browser else { return }
        let ids = (view.indexPathsForSelectedItems ?? []).compactMap { item(at: $0)?.id }
        browser.setSelection(Set(ids), in: browser.layout.focusedPane.activeTabID)
    }

    func collectionView(
        _ view: UICollectionView, performPrimaryActionForItemAt indexPath: IndexPath
    ) {
        guard let item = item(at: indexPath) else { return }
        content?.actions.open(item)
    }

    func collectionView(
        _ view: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let actions = content?.actions else { return nil }
        let items = indexPaths.compactMap { item(at: $0) }
        return UIContextMenuConfiguration(actionProvider: { _ in
            UIMenu(
                children: ItemCommands.sections(for: items, actions: actions).map { section in
                    UIMenu(options: .displayInline, children: section.map(Self.action))
                })
        })
    }

    private static func action(for command: ItemCommand) -> UIAction {
        var attributes: UIMenuElement.Attributes = []
        if command.isDestructive { attributes.insert(.destructive) }
        if !command.isEnabled { attributes.insert(.disabled) }
        return UIAction(
            title: command.title, image: UIImage(systemName: command.symbol),
            attributes: attributes
        ) { _ in command.perform() }
    }
}

/// The table's collection view: the first responder in its window, so the system's Undo and
/// Redo, from the keyboard, the menu bar and the three-finger swipe, take from the app's one
/// history rather than the window's own (ADR 0047).
final class FolderCollectionView: UICollectionView {
    var sharedUndo: UndoManager?

    override var undoManager: UndoManager? { sharedUndo }

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() }
    }

    /// A touch in the table takes the keyboard back, as an alert or the search field may
    /// have held it, so Undo reaches the app's history again.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isFirstResponder { becomeFirstResponder() }
        super.touchesBegan(touches, with: event)
    }
}
