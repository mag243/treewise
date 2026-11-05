/// A click on an item's name, and whether it renames the item once the
/// double-click interval passes without a second click, as in Finder and
/// Explorer (ADR 0039).
public struct ClickRename: Equatable, Sendable {
    /// Whether the item was the only selected item before the click.
    public var wasOnlySelection: Bool
    /// Whether the click is on the item's name, not its icon or another column.
    public var isOnName: Bool
    /// The click count of the click: 2 for the second click of a double-click.
    public var clickCount: Int
    /// Whether ⌘, ⇧, ⌥ or ⌃ is held.
    public var hasModifiers: Bool
    /// Whether the pointer moved far enough to drag the item.
    public var dragged: Bool

    public init(
        wasOnlySelection: Bool, isOnName: Bool, clickCount: Int, hasModifiers: Bool, dragged: Bool
    ) {
        self.wasOnlySelection = wasOnlySelection
        self.isOnName = isOnName
        self.clickCount = clickCount
        self.hasModifiers = hasModifiers
        self.dragged = dragged
    }

    /// Whether the click starts a rename after the wait: a single plain click
    /// on the name of the item that was the only selection, without a drag.
    public var begins: Bool {
        wasOnlySelection && isOnName && clickCount == 1 && !hasModifiers && !dragged
    }
}
