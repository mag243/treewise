import AppKit

/// Opens a sidebar folder during a drag only once the pointer rests on it,
/// like spring-loaded folders in Finder. AppKit opens every folder a drag
/// crosses at once, which pushes the folder the user aims for away from the
/// pointer.
@MainActor
final class SidebarSpringLoading {
    /// How long a drag rests on a folder before it opens.
    static let delay: Duration = .seconds(1)

    private var isDragging = false
    private var hovered: SidebarNode?
    /// The folders opened during this drag, which may finish opening when
    /// their subfolders arrive later.
    private var opened: Set<ObjectIdentifier> = []
    private var timer: Task<Void, Never>?

    /// The drag is over `node`, or over no folder; `open` opens a folder the
    /// drag has rested on long enough.
    func hover(_ node: SidebarNode?, open: @escaping (SidebarNode) -> Void) {
        isDragging = true
        guard node !== hovered else { return }
        hovered = node
        timer?.cancel()
        guard let node else { return }
        timer = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled, let self, self.hovered === node else { return }
            self.opened.insert(ObjectIdentifier(node))
            open(node)
        }
    }

    /// Whether a folder may open now: always, except during a drag that has
    /// not rested on it.
    func mayExpand(_ node: SidebarNode) -> Bool {
        !isDragging || opened.contains(ObjectIdentifier(node))
    }

    /// The drag left the sidebar, dropped or ended.
    func end() {
        isDragging = false
        hovered = nil
        opened = []
        timer?.cancel()
    }
}
