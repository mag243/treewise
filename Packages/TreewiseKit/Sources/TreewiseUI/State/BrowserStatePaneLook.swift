import TreewiseCore

/// Each pane's sort order and view (ADR 0154).
extension BrowserState {
    /// How the focused pane's list is sorted; each pane of a split keeps its own.
    public var sort: ItemSort { sort(of: layout.focusedPaneIndex) }

    /// How a pane's list is sorted.
    public func sort(of pane: Int) -> ItemSort { look(of: pane).sort }

    /// Whether a pane shows its folder as a list or as icons.
    public func viewMode(of pane: Int) -> ViewMode { look(of: pane).viewMode }

    /// Shows a pane's folder as a list or as icons.
    public func setViewMode(_ mode: ViewMode, of pane: Int) {
        updateLook(of: pane) { $0.viewMode = mode }
    }

    /// A pane's look; the first pane's for an index that has none, as a view may ask
    /// once more after its pane closed.
    func look(of pane: Int) -> PaneLook {
        paneLooks.indices.contains(pane) ? paneLooks[pane] : paneLooks[0]
    }

    /// Adds a look for a pane just added after the others: the focused pane's, so a new
    /// half shows its folder as the half it came from.
    func addLookForNewPane(from pane: Int) {
        paneLooks.append(look(of: pane))
    }

    /// Removes the look of a pane just closed.
    func removeLook(at pane: Int) {
        guard paneLooks.count > 1, paneLooks.indices.contains(pane) else { return }
        paneLooks.remove(at: pane)
    }

    /// Changes a pane's look; nothing for an index that has none.
    func updateLook(of pane: Int, _ change: (inout PaneLook) -> Void) {
        guard paneLooks.indices.contains(pane) else { return }
        change(&paneLooks[pane])
    }
}
