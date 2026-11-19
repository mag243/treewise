import TreewiseCore

/// Which rows a click and a rectangle select with a trackpad or mouse on the iPad, as on the
/// Mac (ADR 0136): a click selects the row alone, ⌘ adds or removes it, ⇧ selects from the
/// row clicked before; a rectangle selects the rows it touches, with ⌘ or ⇧ in addition.
public struct PointerSelection: Equatable, Sendable {
    /// The keys held with a click or a rectangle.
    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
    }

    /// The rows selected.
    public var selection: Set<FileItem.ID>
    /// The row a ⇧-click selects from: the last one clicked without ⇧.
    public var anchor: FileItem.ID?

    public init(selection: Set<FileItem.ID> = [], anchor: FileItem.ID? = nil) {
        self.selection = selection
        self.anchor = anchor
    }

    /// The selection after a click on `row`, or on empty space when `row` is `nil`, among
    /// `items` in their order.
    public func clicked(
        _ row: FileItem.ID?, modifiers: Modifiers = [], in items: [FileItem.ID]
    ) -> PointerSelection {
        guard let row else {
            return modifiers.isEmpty ? PointerSelection() : self
        }
        if modifiers.contains(.shift), let anchor,
            let from = items.firstIndex(of: anchor), let to = items.firstIndex(of: row)
        {
            let range = min(from, to)...max(from, to)
            return PointerSelection(selection: Set(items[range]), anchor: anchor)
        }
        if modifiers.contains(.command) {
            return PointerSelection(selection: selection.symmetricDifference([row]), anchor: row)
        }
        return PointerSelection(selection: [row], anchor: row)
    }

    /// The selection after a rectangle touched the rows `touched`.
    public func banded(_ touched: Set<FileItem.ID>, modifiers: Modifiers = []) -> PointerSelection {
        PointerSelection(
            selection: modifiers.isEmpty ? touched : selection.union(touched), anchor: anchor)
    }

    /// The selection a right-click on `row` shows its menu for: the selection when the row is
    /// in it, else the row alone.
    public func rightClicked(_ row: FileItem.ID) -> PointerSelection {
        selection.contains(row) ? self : PointerSelection(selection: [row], anchor: row)
    }
}
