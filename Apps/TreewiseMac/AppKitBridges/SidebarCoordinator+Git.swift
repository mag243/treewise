import AppKit
import TreewiseCore

extension SidebarCoordinator {
    /// Marks the rows on screen again, after git status was turned on or off; a row made
    /// later reads it when it is shown (ADR 0149).
    func markRepositories() {
        guard let outline else { return }
        outline.enumerateAvailableRowViews { _, row in
            guard let node = outline.item(atRow: row) as? SidebarNode,
                case .item(let folder) = node.content
            else { return }
            let cell = outline.view(atColumn: 0, row: row, makeIfNecessary: false)
            (cell as? SidebarCell)?.marksRepository = marksRepository(folder.id)
        }
    }
}
