/// Decides whether dropped items can land on a target, and whether they move or
/// copy (PLAN.md §4.1, ADR 0003).
public enum TransferPlanner {
    /// Returns the mode of dropping `items` on `target`, or `nil` when the drop
    /// is not allowed.
    ///
    /// The drop is not allowed when there are no items, when the target is not a
    /// container, when any item cannot be moved, when any item is the target or
    /// one of its containers, or when a move would leave every item where it is.
    /// Otherwise ⌥ copies, ⌘ moves, and without either the items move when they
    /// are all on the target's volume and copy when they are not.
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
        guard items.allSatisfy({ $0.isMovable && !targetAndAncestors.contains($0.id) }) else {
            return nil
        }
        let mode = mode(of: items, onto: target, modifiers: modifiers)
        if mode == .move && items.allSatisfy({ $0.parentID == target.id }) {
            return nil
        }
        return mode
    }

    private static func mode(
        of items: [FileItem], onto target: FileItem, modifiers: DropModifiers
    ) -> TransferMode {
        if modifiers.contains(.option) { return .copy }
        if modifiers.contains(.command) { return .move }
        return items.allSatisfy { $0.volume == target.volume } ? .move : .copy
    }
}
