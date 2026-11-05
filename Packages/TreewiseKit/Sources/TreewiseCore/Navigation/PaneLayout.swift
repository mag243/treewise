/// The panes of a window: one, or two side by side in split view.
///
/// Invariant: there are one or two panes, and `focusedPaneIndex` is one of them.
public struct PaneLayout: Sendable, Hashable {
    /// The most panes a window shows side by side.
    public static let maximumPanes = 2

    /// The panes, from left to right.
    public private(set) var panes: [PaneModel]
    /// The pane that receives commands such as paste and New Folder.
    public private(set) var focusedPaneIndex = 0

    /// Creates a layout with one pane showing a folder.
    public init(at folder: FileItem.ID) {
        panes = [PaneModel(at: folder)]
    }

    /// Creates a layout from panes, such as a restored window's (ADR 0024).
    ///
    /// Precondition: there are one or two panes, and `focused` is one of them.
    public init(panes: [PaneModel], focused: Int) {
        precondition(
            (1...Self.maximumPanes).contains(panes.count) && panes.indices.contains(focused),
            "there are one or two panes, and focused is one of them")
        self.panes = panes
        focusedPaneIndex = focused
    }

    /// Whether two panes are shown.
    public var isSplit: Bool { panes.count == Self.maximumPanes }

    /// The pane that receives commands.
    public var focusedPane: PaneModel { panes[focusedPaneIndex] }

    /// Returns the pane at `index`, or `nil` when there is none, such as the
    /// right pane just after split view was turned off.
    public func pane(at index: Int) -> PaneModel? {
        panes.indices.contains(index) ? panes[index] : nil
    }

    /// Turns split view on with a second pane showing `folder`, which gets the
    /// focus; or turns it off, merging the tabs of both panes into one, left
    /// pane first, with the focused pane's active tab active.
    public mutating func toggleSplit(newPaneAt folder: FileItem.ID) {
        if isSplit {
            let active = focusedPane.activeTabID
            panes = [PaneModel(tabs: panes[0].tabs + panes[1].tabs, active: active)]
            focusedPaneIndex = 0
        } else {
            panes.append(PaneModel(at: folder))
            focusedPaneIndex = panes.count - 1
        }
    }

    /// Closes a pane of a split, with its tabs; the other pane stays, focused.
    ///
    /// - Returns: `false` when the layout is not split or has no pane at `index`.
    @discardableResult
    public mutating func closePane(at index: Int) -> Bool {
        guard isSplit, panes.indices.contains(index) else { return false }
        panes.remove(at: index)
        focusedPaneIndex = 0
        return true
    }

    /// Gives a pane the focus.
    ///
    /// - Returns: `false` when there is no pane at `index`.
    @discardableResult
    public mutating func focusPane(at index: Int) -> Bool {
        guard panes.indices.contains(index) else { return false }
        focusedPaneIndex = index
        return true
    }

    /// Changes the focused pane, for example to open a tab in it.
    public mutating func updateFocusedPane(_ change: (inout PaneModel) -> Void) {
        change(&panes[focusedPaneIndex])
    }

    /// Returns the tab with an identity, in whichever pane it is.
    public func tab(_ id: TabModel.ID) -> TabModel? {
        panes.lazy.compactMap { $0.tab(id) }.first
    }

    /// Changes a tab in whichever pane it is, without moving the focus.
    ///
    /// - Returns: `false` when no pane has such a tab.
    @discardableResult
    public mutating func updateTab(_ id: TabModel.ID, _ change: (inout TabModel) -> Void) -> Bool {
        guard let index = panes.firstIndex(where: { $0.tab(id) != nil }) else { return false }
        return panes[index].updateTab(id, change)
    }
}
