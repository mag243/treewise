import AppKit
import TreewiseCore
import TreewiseUI

/// Dragging from and onto the icon view (ADR 0003, ADR 0025), as in the list:
/// tiles go on the drag pasteboard as file URLs; a drop on a folder's tile
/// lands in that folder, anywhere else in the folder the view shows.
extension FileGridCoordinator {
    func collectionView(
        _ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath
    ) -> (any NSPasteboardWriting)? {
        guard items.indices.contains(indexPath.item) else { return nil }
        return items[indexPath.item].id.diskURL as NSURL?
    }

    func collectionView(
        _ collectionView: NSCollectionView, validateDrop draggingInfo: any NSDraggingInfo,
        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        let target = target(
            at: proposedDropIndexPath.pointee as IndexPath, proposedDropOperation.pointee)
        return DropRouting.operation(of: draggingInfo, over: target)
    }

    func collectionView(
        _ collectionView: NSCollectionView, acceptDrop draggingInfo: any NSDraggingInfo,
        indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        DropRouting.perform(
            draggingInfo.draggingPasteboard, on: target(at: indexPath, dropOperation),
            with: actions?.drop)
    }

    func collectionView(
        _ collectionView: NSCollectionView, draggingSession session: NSDraggingSession,
        endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation
    ) {
        DropRouting.finish()
    }

    /// The folder a drop lands in: the tile's when it is on a folder, else
    /// the folder the view shows.
    private func target(at indexPath: IndexPath, _ operation: NSCollectionView.DropOperation)
        -> FileItem?
    {
        let index = indexPath.item
        guard operation == .on, items.indices.contains(index), items[index].isContainer else {
            return folder
        }
        return items[index]
    }
}
