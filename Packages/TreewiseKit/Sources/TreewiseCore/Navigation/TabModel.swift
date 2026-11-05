import Foundation

/// One tab of a pane: a folder with its own back and forward history.
public struct TabModel: Identifiable, Sendable, Hashable {
    /// Identifies a tab across panes and windows.
    public struct ID: Hashable, Sendable {
        private let value = UUID()
    }

    /// The tab's identity; every new tab gets a fresh one.
    public let id = ID()
    /// The folders the tab has shown.
    public var history: NavigationHistory

    /// Creates a tab showing a folder.
    public init(at folder: FileItem.ID) {
        history = NavigationHistory(at: folder)
    }

    /// The folder the tab shows.
    public var folder: FileItem.ID { history.current }
}
