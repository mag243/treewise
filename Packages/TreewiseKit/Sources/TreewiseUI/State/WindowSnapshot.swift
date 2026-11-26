import Foundation
import TreewiseCore

/// What a restart brings back of a window: its panes with the folders of their
/// tabs, the focused pane, the sort order and the view (ADR 0024). History is
/// not kept.
public struct WindowSnapshot: Codable, Equatable, Sendable {
    /// One pane: the folders of its tabs, left to right, the active one, and the pane's
    /// own sort order and view (ADR 0154), absent in snapshots made before panes had them.
    public struct Pane: Codable, Equatable, Sendable {
        public var folders: [String]
        public var activeTab: Int
        public var sortColumn: String?
        // swiftlint:disable:next discouraged_optional_boolean - absent in older snapshots
        public var ascending: Bool?
        public var viewMode: ViewMode?
    }

    public var panes: [Pane]
    public var focusedPane: Int
    /// The focused pane's sort order, which a pane saved without its own takes.
    public var sortColumn: String
    public var ascending: Bool
    /// The focused pane's view, which a pane saved without its own takes; absent in
    /// snapshots made before there was an icon view.
    public var viewMode: ViewMode?
    /// The sidebar's width in points (ADR 0093); absent in snapshots made before it was
    /// kept.
    public var sidebarWidth: Double?

    /// Describes a window's layout, with one sort order and view for every pane.
    public init(layout: PaneLayout, sort: ItemSort, viewMode: ViewMode) {
        self.init(
            layout: layout,
            looks: Array(
                repeating: PaneLook(sort: sort, viewMode: viewMode), count: layout.panes.count))
    }

    /// Describes a window's layout and each pane's sort order and view.
    ///
    /// Precondition: `looks` has one look for each pane.
    public init(layout: PaneLayout, looks: [PaneLook]) {
        precondition(looks.count == layout.panes.count, "looks has one look for each pane")
        panes = zip(layout.panes, looks).map { pane, look in
            Pane(
                folders: pane.tabs.map(\.folder.rawValue),
                activeTab: pane.tabs.firstIndex { $0.id == pane.activeTabID } ?? 0,
                sortColumn: look.sort.column.rawValue, ascending: look.sort.ascending,
                viewMode: look.viewMode)
        }
        focusedPane = layout.focusedPaneIndex
        let focused = looks[layout.focusedPaneIndex]
        sortColumn = focused.sort.column.rawValue
        ascending = focused.sort.ascending
        viewMode = focused.viewMode
    }

    /// The window at `folder` alone, in one pane with one tab, with this window's sort
    /// order and view, as a window a folder opens in shows it (ADR 0134).
    public func showing(_ folder: FileItem.ID) -> WindowSnapshot {
        var shown = self
        shown.panes = [Pane(folders: [folder.rawValue], activeTab: 0)]
        shown.focusedPane = 0
        return shown
    }

    /// The layout, sort order and view to restore, with only the tabs whose folder
    /// `isUsable`, and only panes that keep a tab; `nil` when none does. An
    /// active tab or focused pane that is left out falls back to the first.
    public func restored(isUsable: (FileItem.ID) -> Bool) -> RestoredWindow? {
        var models: [PaneModel] = []
        var looks: [PaneLook] = []
        var focused = 0
        for (index, pane) in panes.prefix(PaneLayout.maximumPanes).enumerated() {
            let kept = pane.folders.indices.filter { isUsable(FileItem.ID(pane.folders[$0])) }
            guard !kept.isEmpty else { continue }
            let tabs = kept.map { TabModel(at: FileItem.ID(pane.folders[$0])) }
            let active = kept.firstIndex(of: pane.activeTab).map { tabs[$0].id }
            if index == focusedPane { focused = models.count }
            models.append(PaneModel(tabs: tabs, active: active))
            looks.append(look(of: pane))
        }
        guard !models.isEmpty else { return nil }
        let window = look(of: nil)
        return RestoredWindow(
            layout: PaneLayout(panes: models, focused: focused),
            sort: window.sort, viewMode: window.viewMode, paneLooks: looks,
            sidebarWidth: sidebarWidth)
    }

    /// A pane's saved sort order and view, each falling back to the window's; the window's
    /// alone for `nil`.
    private func look(of pane: Pane?) -> PaneLook {
        let column = SortColumn(rawValue: pane?.sortColumn ?? sortColumn) ?? .name
        return PaneLook(
            sort: ItemSort(column: column, ascending: pane?.ascending ?? ascending),
            viewMode: pane?.viewMode ?? viewMode ?? .list)
    }
}
