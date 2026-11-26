import TreewiseCore

/// Split View in a window on the Mac: two folders side by side, the active half acted on
/// (ADR 0154). Unlike `toggleSplit(newPaneAt:)`, which merges both panes' tabs as the iPad
/// wants, each half here shows one folder, and the active half's folder outlives the split.
extension BrowserState {
    /// The divider's place between two equal halves, as the left half's share.
    public static let equalHalves = 0.5

    /// What separates the two folders' names in a split window's title.
    static let titleSeparator = " | "

    /// Shows two folders side by side: a right half on the active folder, which gets the
    /// focus. A window already split keeps its halves.
    public func showSplitView() async {
        guard !layout.isSplit else { return }
        addLookForNewPane(from: layout.focusedPaneIndex)
        layout.toggleSplit(newPaneAt: layout.focusedPane.activeTab.folder)
        await load(layout.focusedPane.activeTabID)
    }

    /// Shows the active half alone, with its folder; the other half is closed.
    public func hideSplitView() {
        guard layout.isSplit else { return }
        let other = layout.panes.indices.first { $0 != layout.focusedPaneIndex }
        guard let other else { return }
        let closed = layout.panes[other].tabs.map(\.id)
        layout.closePane(at: other)
        removeLook(at: other)
        for tab in closed { contents[tab] = nil }
        updateWatches()
    }

    /// Reads a half's folder again without giving it the focus, as when a download in the
    /// other half ends; nothing for a half that is gone.
    public func readAgain(pane: Int) async {
        guard let tab = layout.pane(at: pane)?.activeTabID else { return }
        await load(tab)
    }

    /// The window's title: the name of the folder it shows, or of both halves' folders,
    /// left first, when split; `nil` while no folder has been read.
    public var windowTitle: String? {
        let names = layout.panes.compactMap { content(of: $0.activeTabID).folder?.name }
        return names.isEmpty ? nil : names.joined(separator: Self.titleSeparator)
    }
}
