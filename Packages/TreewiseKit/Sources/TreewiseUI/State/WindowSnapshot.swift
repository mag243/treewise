import Foundation
import TreewiseCore

/// How a window shows folders: as a list or as icons (ADR 0025).
public enum ViewMode: String, Codable, Sendable {
    case list, icons
}

/// A window as `WindowSnapshot.restored` gives it back.
public struct RestoredWindow {
    public var layout: PaneLayout
    public var sort: ItemSort
    public var viewMode: ViewMode
}

/// What a restart brings back of a window: its panes with the folders of their
/// tabs, the focused pane, the sort order and the view (ADR 0024). History is
/// not kept.
public struct WindowSnapshot: Codable, Equatable, Sendable {
    /// One pane: the folders of its tabs, left to right, and the active one.
    public struct Pane: Codable, Equatable, Sendable {
        public var folders: [String]
        public var activeTab: Int
    }

    public var panes: [Pane]
    public var focusedPane: Int
    public var sortColumn: String
    public var ascending: Bool
    /// The view; absent in snapshots made before there was an icon view.
    public var viewMode: ViewMode?

    /// Describes a window's layout, sort order and view.
    public init(layout: PaneLayout, sort: ItemSort, viewMode: ViewMode) {
        panes = layout.panes.map { pane in
            Pane(
                folders: pane.tabs.map(\.folder.rawValue),
                activeTab: pane.tabs.firstIndex { $0.id == pane.activeTabID } ?? 0)
        }
        focusedPane = layout.focusedPaneIndex
        sortColumn = "\(sort.column)"
        ascending = sort.ascending
        self.viewMode = viewMode
    }

    /// The layout, sort order and view to restore, with only the tabs whose folder
    /// `isUsable`, and only panes that keep a tab; `nil` when none does. An
    /// active tab or focused pane that is left out falls back to the first.
    public func restored(isUsable: (FileItem.ID) -> Bool) -> RestoredWindow? {
        var models: [PaneModel] = []
        var focused = 0
        for (index, pane) in panes.prefix(PaneLayout.maximumPanes).enumerated() {
            let kept = pane.folders.indices.filter { isUsable(FileItem.ID(pane.folders[$0])) }
            guard !kept.isEmpty else { continue }
            let tabs = kept.map { TabModel(at: FileItem.ID(pane.folders[$0])) }
            let active = kept.firstIndex(of: pane.activeTab).map { tabs[$0].id }
            if index == focusedPane { focused = models.count }
            models.append(PaneModel(tabs: tabs, active: active))
        }
        guard !models.isEmpty else { return nil }
        let column = SortColumn.allCases.first { "\($0)" == sortColumn } ?? .name
        return RestoredWindow(
            layout: PaneLayout(panes: models, focused: focused),
            sort: ItemSort(column: column, ascending: ascending), viewMode: viewMode ?? .list)
    }
}
