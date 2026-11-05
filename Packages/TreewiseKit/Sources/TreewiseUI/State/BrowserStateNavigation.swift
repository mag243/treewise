import TreewiseCore

extension BrowserState {
    /// Shows a folder in a pane's active tab.
    public func navigate(pane: Int, to folder: FileItem.ID) async {
        await changeActiveTab(of: pane) { $0.history.navigate(to: folder) }
    }

    /// Shows the previous folder of a pane's active tab.
    public func goBack(pane: Int) async {
        await changeActiveTab(of: pane) { $0.history.goBack() }
    }

    /// Shows the next folder of a pane's active tab.
    public func goForward(pane: Int) async {
        await changeActiveTab(of: pane) { $0.history.goForward() }
    }

    /// Shows the folder that contains the one a pane's active tab shows.
    public func goUp(pane: Int) async {
        guard layout.panes.indices.contains(pane) else { return }
        let parent = content(of: layout.panes[pane].activeTabID).ancestry.first
        await changeActiveTab(of: pane) { $0.history.goUp { _ in parent } }
    }

    /// Reads the folder a pane's active tab shows again (⌘R), for a change no
    /// watcher reported, such as on a network volume.
    public func refresh(pane: Int) async {
        guard layout.focusPane(at: pane) else { return }
        await load(layout.focusedPane.activeTabID)
    }

    /// Opens an item: a container in the browser, where `placement` says;
    /// anything else is handed back for the app to open.
    @discardableResult
    public func open(_ item: FileItem, pane: Int, in placement: OpenPlacement) async -> OpenResult {
        guard item.isContainer else { return .openFile(item) }
        switch placement {
        case .samePane:
            await navigate(pane: pane, to: item.id)
        case .newTab:
            await openTab(pane: pane, at: item.id)
        case .otherPane:
            let other = layout.panes.indices.first { $0 != pane } ?? pane
            await navigate(pane: other, to: item.id)
        }
        return .navigated
    }

    /// Shows the focused pane's next tab, the first after the last.
    public func showNextTab() async {
        layout.updateFocusedPane { $0.activateNextTab() }
        await load(layout.focusedPane.activeTabID)
    }

    /// Shows the focused pane's previous tab, the last before the first.
    public func showPreviousTab() async {
        layout.updateFocusedPane { $0.activatePreviousTab() }
        await load(layout.focusedPane.activeTabID)
    }

    /// Closes the focused pane's active tab; with its last tab, the pane of a
    /// split. The window's last tab stays, for the window to close.
    public func closeActiveTab() -> TabClosing {
        let pane = layout.focusedPaneIndex
        let tab = layout.focusedPane.activeTabID
        if layout.focusedPane.tabs.count > 1 {
            closeTab(pane: pane, tab: tab)
            return .tab
        }
        guard layout.closePane(at: pane) else { return .window }
        contents[tab] = nil
        updateWatches()
        return .pane
    }

    /// Opens a tab showing a folder in a pane and makes it active.
    public func openTab(pane: Int, at folder: FileItem.ID) async {
        guard layout.focusPane(at: pane) else { return }
        layout.updateFocusedPane { $0.openTab(at: folder) }
        await load(layout.focusedPane.activeTabID)
    }

    /// Makes a tab of a pane active.
    public func activateTab(pane: Int, tab: TabModel.ID) async {
        guard layout.focusPane(at: pane) else { return }
        layout.updateFocusedPane { $0.activateTab(tab) }
        await load(tab)
    }

    /// Closes a tab of a pane; the last tab of a pane stays.
    public func closeTab(pane: Int, tab: TabModel.ID) {
        guard layout.focusPane(at: pane) else { return }
        var closed = false
        layout.updateFocusedPane { closed = $0.closeTab(tab) }
        guard closed else { return }
        contents[tab] = nil
        updateWatches()
    }

    /// Turns split view on, with a second pane showing `folder`, or off,
    /// merging the tabs of both panes.
    public func toggleSplit(newPaneAt folder: FileItem.ID) async {
        layout.toggleSplit(newPaneAt: folder)
        if layout.isSplit {
            await load(layout.focusedPane.activeTabID)
        } else {
            updateWatches()
        }
    }

    private func changeActiveTab(of pane: Int, _ change: (inout TabModel) -> Void) async {
        guard layout.focusPane(at: pane) else { return }
        let tab = layout.focusedPane.activeTabID
        let before = layout.focusedPane.activeTab.folder
        layout.updateFocusedPane { $0.updateActiveTab(change) }
        guard layout.focusedPane.activeTab.folder != before else { return }
        contents[tab] = TabContent()
        await load(tab)
    }
}

extension BrowserState {
    /// The location the folder a pane shows is in: the folder itself or the
    /// nearest folder above it that the sidebar lists; `nil` when none is.
    public func locationShown(in pane: Int) -> FileItem.ID? {
        guard layout.panes.indices.contains(pane) else { return nil }
        let tab = layout.panes[pane].activeTab
        let listed = Set(locations.map(\.id))
        return ([tab.folder] + content(of: tab.id).ancestry).first(where: listed.contains)
    }
}
