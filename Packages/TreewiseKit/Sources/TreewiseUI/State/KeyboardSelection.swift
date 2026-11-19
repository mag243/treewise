import TreewiseCore

/// The selection the arrow keys move on the iPad (ADR 0135): an arrow selects the item
/// beside the cursor alone, and with ⇧ the items from the anchor to it.
///
/// Invariant: `cursor` and `anchor` are both set or both `nil`.
public struct KeyboardSelection: Equatable, Sendable {
    /// Which way an arrow moves.
    public enum Direction: Sendable {
        case up, down
    }

    /// The items selected.
    public var selection: Set<FileItem.ID>
    /// The item the last arrow moved to; `nil` when the selection was made otherwise.
    public var cursor: FileItem.ID?
    /// Where ⇧ extends from: the item the last arrow without ⇧ moved to.
    public var anchor: FileItem.ID?

    public init(
        selection: Set<FileItem.ID> = [], cursor: FileItem.ID? = nil, anchor: FileItem.ID? = nil
    ) {
        precondition((cursor == nil) == (anchor == nil), "cursor and anchor are set together")
        self.selection = selection
        self.cursor = cursor
        self.anchor = anchor
    }

    /// The selection after an arrow in `direction` over `items`, in their order: from the
    /// cursor, or else the last selected item, to the item beside it, stopping at the ends;
    /// from nothing, down selects the first item and up the last.
    public func moved(
        _ direction: Direction, in items: [FileItem.ID], extending: Bool = false
    ) -> KeyboardSelection {
        guard !items.isEmpty else { return KeyboardSelection() }
        let target = Self.index(after: startIndex(in: items), going: direction, count: items.count)
        let moved = items[target]
        guard extending, let anchor, let anchorIndex = items.firstIndex(of: anchor) else {
            return KeyboardSelection(selection: [moved], cursor: moved, anchor: moved)
        }
        let range = min(anchorIndex, target)...max(anchorIndex, target)
        return KeyboardSelection(selection: Set(items[range]), cursor: moved, anchor: anchor)
    }

    /// Where the arrow starts: the cursor, else the last selected item; `nil` from nothing.
    private func startIndex(in items: [FileItem.ID]) -> Int? {
        if let cursor { return items.firstIndex(of: cursor) }
        return items.lastIndex { selection.contains($0) }
    }

    private static func index(after start: Int?, going direction: Direction, count: Int) -> Int {
        guard let start else { return direction == .down ? 0 : count - 1 }
        switch direction {
        case .down: return min(start + 1, count - 1)
        case .up: return max(start - 1, 0)
        }
    }
}
