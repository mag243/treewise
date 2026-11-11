import TreewiseCore

/// A tab group as `SessionSnapshot.restored` gives it back.
public struct RestoredGroup {
    /// The tabs from left to right; never empty.
    public var tabs: [RestoredWindow]
    /// Which of `tabs` is selected.
    public var selectedTab: Int
}

/// What a restart of the iOS app brings back (ADR 0038; on the Mac AppKit
/// restores the windows, ADR 0083): the tab groups from
/// front to back, each with its tabs from left to right and the selected one.
/// A window without tabs is a group of one.
public struct SessionSnapshot: Codable, Equatable, Sendable {
    /// One tab group: a window per tab, as `WindowSnapshot` keeps it.
    public struct Group: Codable, Equatable, Sendable {
        public var tabs: [WindowSnapshot]
        public var selectedTab: Int

        public init(tabs: [WindowSnapshot], selectedTab: Int) {
            self.tabs = tabs
            self.selectedTab = selectedTab
        }
    }

    public var groups: [Group]

    public init(groups: [Group]) {
        self.groups = groups
    }

    /// A session of one window, as the release before ADR 0038 kept it.
    public init(window: WindowSnapshot) {
        groups = [Group(tabs: [window], selectedTab: 0)]
    }

    /// The groups to restore, with only the tabs that have a folder that
    /// `isUsable`, and only groups that keep a tab; empty when none does. A
    /// selected tab that is left out falls back to the first.
    public func restored(isUsable: (FileItem.ID) -> Bool) -> [RestoredGroup] {
        groups.compactMap { group in
            let kept = group.tabs.indices.compactMap { index in
                group.tabs[index].restored(isUsable: isUsable).map { (index, $0) }
            }
            guard !kept.isEmpty else { return nil }
            let selected = kept.firstIndex { $0.0 == group.selectedTab } ?? 0
            return RestoredGroup(tabs: kept.map(\.1), selectedTab: selected)
        }
    }
}
