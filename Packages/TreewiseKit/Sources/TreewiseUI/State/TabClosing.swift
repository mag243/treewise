import TreewiseCore

/// What closing the active tab closed (ADR 0022).
public enum TabClosing: Sendable, Equatable {
    /// The tab; its pane has others.
    case tab
    /// The pane of a split, with its last tab.
    case pane
    /// Nothing: it is the window's last tab, so the window closes.
    case window
}
