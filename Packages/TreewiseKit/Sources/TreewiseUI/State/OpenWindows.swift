/// The browser windows that are open, for the session a restart brings back
/// (ADR 0038). A window that closes is left out from then on, also when the
/// window system still lists it: SwiftUI keeps a closed window around.
///
/// Invariant: a window is in the session only between `open` and `close`.
public struct OpenWindows<Window: Hashable> {
    private var windows: Set<Window> = []

    public init() {}

    /// Records that `window` shows a folder.
    public mutating func open(_ window: Window) {
        windows.insert(window)
    }

    /// Records that `window` closed.
    public mutating func close(_ window: Window) {
        windows.remove(window)
    }

    /// The tab groups of the open windows, from front to back, each with its
    /// open tabs from left to right and listed once.
    ///
    /// - Parameters:
    ///   - frontToBack: the windows as the window system orders them, which
    ///     may list closed windows and windows that show no folder.
    ///   - tabs: the tabs of a window's group from left to right, or the
    ///     window alone.
    public func groups(frontToBack: [Window], tabs: (Window) -> [Window]) -> [[Window]] {
        var groups: [[Window]] = []
        var seen: Set<Window> = []
        for window in frontToBack where !seen.contains(window) {
            let group = tabs(window)
            seen.formUnion(group)
            seen.insert(window)
            let open = group.filter(windows.contains)
            if !open.isEmpty { groups.append(open) }
        }
        return groups
    }
}
