/// Decides whether dropped items can land on a target, and whether they move or
/// copy (PLAN.md §4.1, ADR 0003).
public enum TransferPlanner {
    /// Returns the mode of dropping `items` on `target`, or `nil` when the drop
    /// is not allowed.
    ///
    /// The drop is not allowed when there are no items, when the target is not a
    /// container that takes items, when any item cannot be copied, when any item
    /// is the target or one of its containers, or when a move would leave every
    /// item where it is. Otherwise items that would cross the edge of an archive
    /// copy, as an archive's entries move only within it (ADR 0076, ADR 0078), ⌥
    /// copies, ⌘ moves, and without either the items move when they are all on
    /// the target's volume and copy when they are not.
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

    /// How items on the clipboard land on `target`: cut items move, unless
    /// that would cross the edge of an archive, and copied items copy.
    public static func pasteMode(of items: [FileItem], onto target: FileItem, cut: Bool)
        -> TransferMode
    {
        cut && !crossesAnArchive(items, target) ? .move : .copy
    }

    /// Returns why nothing can land on `target`, when there is a reason to
    /// tell: it is inside an archive that cannot change (ADR 0076, ADR 0078).
    public static func refusal(target: FileItem) -> FileSystemError? {
        guard let place = ArchivePath(target.id), !place.isChangeable else { return nil }
        return .archiveReadOnly
    }

    /// Whether an item and the target are not in the same archive, or one
    /// of them is in an archive and the other is not.
    private static func crossesAnArchive(_ items: [FileItem], _ target: FileItem) -> Bool {
        let archive = ArchivePath(target.id)?.archive
        return items.contains { ArchivePath($0.id)?.archive != archive }
    }

    private static func mode(
        of items: [FileItem], onto target: FileItem, modifiers: DropModifiers
    ) -> TransferMode {
        if modifiers.contains(.option) || crossesAnArchive(items, target) { return .copy }
        if modifiers.contains(.command) { return .move }
        return items.allSatisfy { $0.volume == target.volume } ? .move : .copy
    }
}
