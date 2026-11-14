extension FileSystemProviding {
    /// The tree of `folder`: the folder and the folders in it at every depth that
    /// `FolderTree.keeps`, as Save Folder Structure as Template saves it (ADR 0091). Reading
    /// stops, with the reason, beyond `FolderTree.mostFolders` or `FolderTree.mostLevels`.
    public func folderTree(of folder: FileItem) async throws -> FolderTree {
        var count = 0
        return try await tree(of: folder, level: 1, count: &count)
    }

    private func tree(of folder: FileItem, level: Int, count: inout Int) async throws
        -> FolderTree
    {
        guard level <= FolderTree.mostLevels else { throw FolderTree.Problem.tooDeep }
        count += 1
        guard count <= FolderTree.mostFolders else { throw FolderTree.Problem.tooManyFolders }
        var folders: [FolderTree] = []
        for item in try await contents(of: folder.id) where FolderTree.keeps(item) {
            try Task.checkCancellation()
            folders.append(try await tree(of: item, level: level + 1, count: &count))
        }
        return FolderTree(name: folder.name, folders: folders)
    }
}
