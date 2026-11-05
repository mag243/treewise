/// One pane of a window: a row of tabs, one of them active.
///
/// Invariant: there is at least one tab, and `activeTabID` is one of them.
public struct PaneModel: Sendable, Hashable {
    /// The tabs, in the order of the tab strip.
    public private(set) var tabs: [TabModel]
    /// The tab the pane shows.
    public private(set) var activeTabID: TabModel.ID

    /// Creates a pane with one tab showing a folder.
    public init(at folder: FileItem.ID) {
        self.init(tabs: [TabModel(at: folder)])
    }

    /// Creates a pane with tabs, the first one active unless `active` names another.
    ///
    /// Precondition: `tabs` is not empty, and `active` is `nil` or one of them.
    public init(tabs: [TabModel], active: TabModel.ID? = nil) {
        precondition(!tabs.isEmpty, "tabs is not empty")
        let activeID = active ?? tabs[0].id
        precondition(tabs.contains { $0.id == activeID }, "active is one of the tabs")
        self.tabs = tabs
        activeTabID = activeID
    }

    /// The tab the pane shows.
    public var activeTab: TabModel {
        tabs[activeIndex]
    }

    /// Opens a tab showing a folder after the others and makes it active.
    ///
    /// - Returns: the new tab's identity.
    @discardableResult
    public mutating func openTab(at folder: FileItem.ID) -> TabModel.ID {
        let tab = TabModel(at: folder)
        tabs.append(tab)
        activeTabID = tab.id
        return tab.id
    }

    /// Makes a tab active.
    ///
    /// - Returns: `false` when the pane has no such tab.
    @discardableResult
    public mutating func activateTab(_ id: TabModel.ID) -> Bool {
        guard tabs.contains(where: { $0.id == id }) else { return false }
        activeTabID = id
        return true
    }

    /// Closes a tab. When it was active, the tab before it becomes active, or
    /// the next one when it was the first.
    ///
    /// - Returns: `false` when the pane has no such tab or it is the last one.
    @discardableResult
    public mutating func closeTab(_ id: TabModel.ID) -> Bool {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else {
            return false
        }
        tabs.remove(at: index)
        if id == activeTabID {
            activeTabID = tabs[max(0, index - 1)].id
        }
        return true
    }

    /// Makes the tab after the active one active, the first after the last.
    public mutating func activateNextTab() {
        activeTabID = tabs[(activeIndex + 1) % tabs.count].id
    }

    /// Makes the tab before the active one active, the last before the first.
    public mutating func activatePreviousTab() {
        activeTabID = tabs[(activeIndex + tabs.count - 1) % tabs.count].id
    }

    /// Returns the tab with an identity, or `nil` when the pane has none.
    public func tab(_ id: TabModel.ID) -> TabModel? {
        tabs.first { $0.id == id }
    }

    /// Changes a tab, for example to navigate it.
    ///
    /// - Returns: `false` when the pane has no such tab.
    @discardableResult
    public mutating func updateTab(_ id: TabModel.ID, _ change: (inout TabModel) -> Void) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        change(&tabs[index])
        return true
    }

    /// Changes the active tab, for example to navigate it.
    public mutating func updateActiveTab(_ change: (inout TabModel) -> Void) {
        change(&tabs[activeIndex])
    }

    private var activeIndex: Int {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else {
            preconditionFailure("activeTabID is one of the tabs")
        }
        return index
    }
}
