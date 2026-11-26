import AppKit
import TreewiseCore

/// Git status in the tree (ADR 0149): a repository's top folder is marked, and the folders
/// inside it show their state on their icons while the repository is followed.
extension SidebarCoordinator {
    /// Takes the git parts of what the sidebar shows, and marks the rows again when git
    /// status was turned on or off or a repository was read.
    func updateGit(with view: SidebarContent) {
        gitState = view.gitState
        followRepository = view.followRepository
        guard showsGitStatus != view.showsGitStatus || gitRevision != view.gitRevision else {
            return
        }
        showsGitStatus = view.showsGitStatus
        gitRevision = view.gitRevision
        markRepositories()
    }

    /// Marks and badges the rows on screen again, after git status was turned on or off or
    /// a repository was read; a row made later reads them when it is shown. Repositories
    /// whose top folders are open are followed.
    func markRepositories() {
        guard let outline else { return }
        outline.enumerateAvailableRowViews { _, row in
            guard let node = outline.item(atRow: row) as? SidebarNode,
                case .item(let folder) = node.content
            else { return }
            let cell = outline.view(atColumn: 0, row: row, makeIfNecessary: false)
            (cell as? SidebarCell)?.marksRepository = marksRepository(folder.id)
            (cell as? SidebarCell)?.gitState = gitState(folder.id)
            if outline.isItemExpanded(node) { followRepository(openIn: node) }
        }
    }

    /// Follows the repository whose top folder `node` shows, while the row stays open.
    func followRepository(openIn node: SidebarNode) {
        let row = ObjectIdentifier(node)
        guard let folder = node.item?.id, marksRepository(folder), !gitFollows.watches(row)
        else { return }
        let follow = followRepository
        gitFollows.add(Task { await follow(folder) }, for: row)
    }
}
