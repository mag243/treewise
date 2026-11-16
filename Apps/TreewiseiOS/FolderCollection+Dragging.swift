import TreewiseCore
import UIKit
import UniformTypeIdentifiers

/// Dragging rows of the table and dropping on them (ADR 0047, 0116). A drag that started
/// in Treewise carries its items as local objects, so the drag rules show while the finger
/// is over a row whether it moves, copies or may not drop there; a drop is still checked as
/// it lands.
extension FolderCollectionCoordinator: UICollectionViewDragDelegate,
    UICollectionViewDropDelegate
{
    func collectionView(
        _ view: UICollectionView, itemsForBeginning session: any UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        dragItems(at: indexPath)
    }

    func collectionView(
        _ view: UICollectionView, itemsForAddingTo session: any UIDragSession,
        at indexPath: IndexPath, point: CGPoint
    ) -> [UIDragItem] {
        dragItems(at: indexPath)
    }

    private func dragItems(at path: IndexPath) -> [UIDragItem] {
        guard let item = item(at: path), let drops = content?.drops else { return [] }
        let dragItem = UIDragItem(itemProvider: drops.provider(for: item))
        dragItem.localObject = item
        return [dragItem]
    }

    func collectionView(_ view: UICollectionView, canHandle session: any UIDropSession) -> Bool {
        session.hasItemsConforming(toTypeIdentifiers: [UTType.treewiseItem.identifier])
    }

    func collectionView(
        _ view: UICollectionView, dropSessionDidUpdate session: any UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard let target = target(at: destinationIndexPath), let drops = content?.drops else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        let intent: UICollectionViewDropProposal.Intent =
            item(at: destinationIndexPath)?.isContainer == true
            ? .insertIntoDestinationIndexPath : .unspecified
        guard let items = localItems(of: session) else {
            return UICollectionViewDropProposal(operation: .copy, intent: intent)
        }
        switch drops.mode(of: items, over: target) {
        case .move: return UICollectionViewDropProposal(operation: .move, intent: intent)
        case .copy: return UICollectionViewDropProposal(operation: .copy, intent: intent)
        case nil: return UICollectionViewDropProposal(operation: .forbidden)
        }
    }

    func collectionView(
        _ view: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator
    ) {
        guard let target = target(at: coordinator.destinationIndexPath),
            let drops = content?.drops
        else { return }
        if let items = localItems(of: coordinator.session) {
            drops.land(items, on: target)
            return
        }
        let providers = coordinator.items.map(\.dragItem.itemProvider)
        Task {
            var dragged: [DraggedItem] = []
            for provider in providers {
                if let item = await DraggedItem.load(from: provider) { dragged.append(item) }
            }
            drops.land(dragged, on: target)
        }
    }

    /// The folder a drop lands in: a folder's row, else the folder shown.
    private func target(at path: IndexPath?) -> FileItem? {
        if let item = item(at: path), item.isContainer { return item }
        return content?.folder
    }

    /// The items a drag from Treewise carries, or `nil` for a drag from elsewhere.
    private func localItems(of session: any UIDropSession) -> [FileItem]? {
        let items = session.localDragSession?.items.compactMap { $0.localObject as? FileItem }
        return items?.isEmpty == false ? items : nil
    }
}
