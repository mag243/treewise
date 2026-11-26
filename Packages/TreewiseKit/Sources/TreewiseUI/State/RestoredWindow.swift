import Foundation
import TreewiseCore

/// A window as `WindowSnapshot.restored` gives it back.
public struct RestoredWindow {
    public var layout: PaneLayout
    /// The focused pane's sort order and view, as the window kept them.
    public var sort: ItemSort
    public var viewMode: ViewMode
    /// Each pane's sort order and view, one for each pane of `layout` (ADR 0154).
    public var paneLooks: [PaneLook]
    /// The sidebar's width in points, when the window kept one (ADR 0093).
    public var sidebarWidth: Double?
}
