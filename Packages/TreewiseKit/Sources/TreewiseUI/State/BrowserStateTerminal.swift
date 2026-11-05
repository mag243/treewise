import TreewiseCore

/// Which folder Open in Terminal opens (ADR 0052).
extension BrowserState {
    /// The folder for the selection of the focused pane; `nil` in This Mac
    /// without a selection, as This Mac is no folder.
    public var terminalFolder: FileItem.ID? {
        terminalFolder(for: selectedItems)
    }

    /// The folder for `items`: one folder itself, one file's enclosing folder,
    /// otherwise the folder shown; `nil` when that is This Mac.
    public func terminalFolder(for items: [FileItem]) -> FileItem.ID? {
        if let item = items.first, items.count == 1 {
            if item.isContainer { return item.id }
            if let folder = item.parentID { return folder }
        }
        let shown = layout.focusedPane.activeTab.folder
        return shown == .computer ? nil : shown
    }
}
