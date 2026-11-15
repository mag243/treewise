import TreewiseCore

/// Where a folder opens (ADR 0022).
public enum OpenPlacement: Sendable, Equatable {
    /// In the pane it was opened from.
    case samePane
    /// In the other pane of a split; in the same pane without a split.
    case otherPane
    /// In a new tab of the pane it was opened from.
    case newTab

    /// Where a double-click or ⌘↓ opens a folder: ⌘ in a new tab, ⌥ opposite
    /// the setting's `preferred` pane, otherwise in that pane.
    public static func forOpening(command: Bool, option: Bool, preferred: OpenPlacement)
        -> OpenPlacement
    {
        if command { return .newTab }
        guard option else { return preferred }
        return preferred == .otherPane ? .samePane : .otherPane
    }
}
