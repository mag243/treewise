import TreewiseCore

extension BrowserState {
    /// Whether the focused pane's folder takes new items: paste and New
    /// Folder. This Mac lists the volumes and takes nothing (ADR 0044).
    public var canAddItems: Bool {
        let tab = layout.focusedPane.activeTab
        return content(of: tab.id).folder?.acceptsItems ?? (tab.folder != .computer)
    }

    /// Moves every tab showing `volume` or a folder on it to This Mac, so
    /// the window holds nothing on the volume before it is ejected (ADR 0044).
    public func leave(volume: FileItem.ID) async {
        let active = Set(layout.panes.map(\.activeTabID))
        for tab in layout.panes.flatMap(\.tabs) where isOn(volume, tab) {
            _ = layout.updateTab(tab.id) { $0.history.navigate(to: .computer) }
            contents[tab.id] = TabContent()
        }
        updateWatches()
        for tab in active where layout.tab(tab)?.folder == .computer {
            await load(tab)
        }
    }

    /// Whether a tab shows `volume` or a folder on it.
    private func isOn(_ volume: FileItem.ID, _ tab: TabModel) -> Bool {
        tab.folder == volume || content(of: tab.id).ancestry.contains(volume)
    }
}
