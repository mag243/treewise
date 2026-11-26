import TreewiseCore

/// How a pane shows its folder: its sort order and its view. Each half of a split window
/// keeps its own, as each has its own column headers and view buttons (ADR 0154).
public struct PaneLook: Equatable, Sendable {
    /// How the pane's list is sorted.
    public var sort: ItemSort
    /// Whether the pane shows its folder as a list or as icons (ADR 0025).
    public var viewMode: ViewMode

    /// Creates a look, by default by name in a list.
    public init(sort: ItemSort = ItemSort(), viewMode: ViewMode = .list) {
        self.sort = sort
        self.viewMode = viewMode
    }
}
