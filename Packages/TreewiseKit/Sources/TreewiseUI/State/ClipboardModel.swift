import TreewiseCore

/// Items cut or copied with ⌘X or ⌘C, waiting for ⌘V (PLAN.md §4.3). Cut
/// items are shown dimmed; pasting cut items moves them and empties the
/// clipboard, pasting copies keeps it for more pastes.
public struct ClipboardModel: Sendable, Equatable {
    /// How the items were put on the clipboard.
    public enum Mode: Sendable, Equatable {
        case cut
        case copy
    }

    /// The items, in the order they were selected.
    public let items: [FileItem]
    /// Whether they were cut or copied.
    public let mode: Mode

    /// Creates a clipboard holding items.
    public init(items: [FileItem], mode: Mode) {
        self.items = items
        self.mode = mode
    }

    /// What pasting does with the items.
    public var transferMode: TransferMode { mode == .cut ? .move : .copy }

    /// Whether an item is shown dimmed, because it is cut.
    public func isCut(_ id: FileItem.ID) -> Bool {
        mode == .cut && items.contains { $0.id == id }
    }

    /// The clipboard without items that were deleted or moved away, or `nil`
    /// when none are left.
    public func removing(_ ids: Set<FileItem.ID>) -> ClipboardModel? {
        let left = items.filter { !ids.contains($0.id) }
        return left.isEmpty ? nil : ClipboardModel(items: left, mode: mode)
    }
}
