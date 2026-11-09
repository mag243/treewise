/// Decides whether dropped items can land on a target, and whether they move or
/// copy (PLAN.md §4.1, ADR 0003).
public enum TransferPlanner {
    /// Returns the mode of dropping `items` on `target`, or `nil` when the drop
    /// is not allowed.
    ///
    /// The drop is not allowed when there are no items, when the target is not a
    /// container that takes items, when any item cannot be copied, when any item
    /// is the target or one of its containers, or when a move would leave every
    /// item where it is. Otherwise items of which one cannot be moved copy, as out
    /// of an archive (ADR 0076), ⌥ copies, ⌘ moves, and without either the items
    /// move when they are all on the target's volume and copy when they are not.
    ///
    /// - Parameter ancestry: returns the containers of an item, nearest first.
    public static func plan(
        items: [FileItem],
        target: FileItem,
        modifiers: DropModifiers,
        ancestry: (FileItem.ID) -> [FileItem.ID]
    ) -> TransferMode? {
        guard !items.isEmpty, target.acceptsItems else { return nil }
        let targetAndAncestors = Set([target.id] + ancestry(target.id))
        guard items.allSatisfy({ $0.isCopyable && !targetAndAncestors.contains($0.id) }) else {
            return nil
        }
        let mode = mode(of: items, onto: target, modifiers: modifiers)
        if mode == .move && items.allSatisfy({ $0.parentID == target.id }) {
            return nil
        }
        return mode
    }

    /// Returns why nothing can land on `target`, when there is a reason to
    /// tell: it is inside an archive (ADR 0076).
    public static func refusal(target: FileItem) -> FileSystemError? {
        target.id.isInsideArchive ? .archiveReadOnly : nil
    }

    private static func mode(
        of items: [FileItem], onto target: FileItem, modifiers: DropModifiers
    ) -> TransferMode {
        if modifiers.contains(.option) || !items.allSatisfy(\.isMovable) { return .copy }
        if modifiers.contains(.command) { return .move }
        return items.allSatisfy { $0.volume == target.volume } ? .move : .copy
    }
}
