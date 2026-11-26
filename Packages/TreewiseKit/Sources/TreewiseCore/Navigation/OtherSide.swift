/// Where "the other side" of a window is: the target of Open on Other Side, ⌥-double-click
/// and Copy and Move to Other Side (ADR 0154).
public enum OtherSide: Sendable, Hashable {
    /// The other half of a split window, by its pane index.
    case pane(Int)
    /// The most recently active other window.
    case otherWindow
    /// No other half or window yet: a window opens beside this one.
    case newWindowBeside

    /// What the other side is wanted for.
    public enum Use: Sendable, Hashable {
        /// Showing a folder there, which may open a window beside.
        case opening
        /// Copying or moving the selection into its folder, which needs one to exist.
        case sending
    }
}

extension PaneLayout {
    /// The other side of the window this layout belongs to: the other half when it is
    /// split, otherwise the other window; with neither, a new window beside when
    /// opening, and `nil` when sending.
    ///
    /// - Parameters:
    ///   - hasOtherWindow: whether another browser window is open.
    ///   - use: whether a folder is opened or the selection is sent there.
    public func otherSide(hasOtherWindow: Bool, for use: OtherSide.Use) -> OtherSide? {
        if isSplit, let other = panes.indices.first(where: { $0 != focusedPaneIndex }) {
            return .pane(other)
        }
        if hasOtherWindow { return .otherWindow }
        return use == .opening ? .newWindowBeside : nil
    }
}
