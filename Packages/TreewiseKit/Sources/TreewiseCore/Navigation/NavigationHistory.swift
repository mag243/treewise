/// The folders a tab has shown, for Back, Forward and Enclosing Folder.
///
/// Invariant: neither stack holds two equal neighbours, and the entries next to
/// `current` differ from it.
public struct NavigationHistory: Sendable, Hashable {
    /// The most entries the back stack keeps; older ones drop off (ADR 0015).
    public static let maximumBackEntries = 100

    /// The folder the tab shows.
    public private(set) var current: FileItem.ID
    /// Earlier folders, oldest first.
    public private(set) var backStack: [FileItem.ID] = []
    /// Folders to go forward to, nearest first.
    public private(set) var forwardStack: [FileItem.ID] = []

    /// Creates a history that starts at a folder.
    public init(at folder: FileItem.ID) {
        current = folder
    }

    /// Whether there is a folder to go back to.
    public var canGoBack: Bool { !backStack.isEmpty }

    /// Whether there is a folder to go forward to.
    public var canGoForward: Bool { !forwardStack.isEmpty }

    /// Shows `folder` and forgets the forward stack; does nothing when the tab
    /// already shows it.
    public mutating func navigate(to folder: FileItem.ID) {
        guard folder != current else { return }
        pushBack(current)
        current = folder
        forwardStack.removeAll()
    }

    /// Shows the previous folder.
    ///
    /// - Returns: `false` when there is none.
    @discardableResult
    public mutating func goBack() -> Bool {
        guard let previous = backStack.popLast() else { return false }
        forwardStack.insert(current, at: 0)
        current = previous
        return true
    }

    /// Shows the next folder.
    ///
    /// - Returns: `false` when there is none.
    @discardableResult
    public mutating func goForward() -> Bool {
        guard !forwardStack.isEmpty else { return false }
        pushBack(current)
        current = forwardStack.removeFirst()
        return true
    }

    /// Shows the folder that contains the current one.
    ///
    /// - Parameter parent: returns the container of a folder, or `nil` for a
    ///   top-level location.
    /// - Returns: `false` when the current folder is a top-level location.
    @discardableResult
    public mutating func goUp(parent: (FileItem.ID) -> FileItem.ID?) -> Bool {
        guard let enclosing = parent(current) else { return false }
        navigate(to: enclosing)
        return true
    }

    /// Forgets folders that were deleted or moved away. When the current folder is one of
    /// them, the tab shows `fallback` instead.
    ///
    /// Precondition: `fallback` is not in `removed`.
    public mutating func removeItems(_ removed: Set<FileItem.ID>, fallback: FileItem.ID) {
        precondition(!removed.contains(fallback), "fallback is not in removed")
        if removed.contains(current) { current = fallback }
        backStack = collapsed(backStack.filter { !removed.contains($0) })
        forwardStack = collapsed(forwardStack.filter { !removed.contains($0) })
        while backStack.last == current { backStack.removeLast() }
        while forwardStack.first == current { forwardStack.removeFirst() }
    }

    private mutating func pushBack(_ folder: FileItem.ID) {
        backStack.append(folder)
        if backStack.count > Self.maximumBackEntries {
            backStack.removeFirst(backStack.count - Self.maximumBackEntries)
        }
    }

    private func collapsed(_ entries: [FileItem.ID]) -> [FileItem.ID] {
        entries.reduce(into: []) { result, entry in
            if result.last != entry { result.append(entry) }
        }
    }
}
