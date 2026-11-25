import TreewiseCore

extension BrowserState {
    /// The state of an item a tab shows in its git repository; `nil` when it is unchanged,
    /// outside a repository, or git status is not shown (ADR 0149).
    public func gitState(of item: FileItem, in tab: TabModel.ID) -> GitItemState? {
        guard let gitStatus, let folder = content(of: tab).readFolder else { return nil }
        return gitStatus.state(of: item.id, in: folder)
    }

    /// The state of the repository that holds the folder a tab shows, for its branch;
    /// `nil` outside a repository or while git status is not shown.
    public func gitRepositoryStatus(of tab: TabModel.ID) -> GitRepositoryStatus? {
        guard let gitStatus, let folder = content(of: tab).readFolder else { return nil }
        return gitStatus.status(of: folder)
    }
}
