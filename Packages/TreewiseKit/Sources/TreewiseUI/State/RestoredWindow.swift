import Foundation
import TreewiseCore

/// A window as `WindowSnapshot.restored` gives it back.
public struct RestoredWindow {
    public var layout: PaneLayout
    public var sort: ItemSort
    public var viewMode: ViewMode
    /// The sidebar's width in points, when the window kept one (ADR 0093).
    public var sidebarWidth: Double?
}
