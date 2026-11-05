import AppKit

/// Keeps the keyboard focus in the active pane (ADR 0022): when ⌘⌥← or ⌘⌥→
/// makes another pane active, or ⌘1 and ⌘2 swap the list and the icon view,
/// the active pane's view takes the focus from the other pane's view or from
/// the window. It never takes it from the search field, the sidebar or a name
/// being edited.
@MainActor
enum PaneFocus {
    /// Gives `view` the focus when the other pane's view or nothing has it.
    static func follow(_ view: NSView) {
        guard let window = view.window, window.firstResponder !== view else { return }
        let current = window.firstResponder
        guard current === window || current is PaneTableView || current is PaneCollectionView
        else { return }
        window.makeFirstResponder(view)
    }
}
