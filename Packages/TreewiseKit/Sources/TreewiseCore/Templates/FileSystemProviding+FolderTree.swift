extension FileSystemProviding {
    /// The tree of `folder`: the folder and the folders in it at every depth that
    /// `FolderTree.keeps`, as Save Folder Structure as Template saves it (ADR 0091). Reading
    /// stops, with the reason, beyond `FolderTree.mostFolders` or `FolderTree.mostLevels`.
    public func folderTree(of folder: FileItem) async throws -> FolderTree {
        try await folderTree(of: folder) { _ in nil }
    }

    /// The tree of `folder` as `folderTree(of:)` reads it, each folder with the name
    /// settings `names` gives for it (ADR 0101).
    public func folderTree(
        of folder: FileItem, names: @Sendable (FileItem) async -> FolderNameSettings?
    ) async throws -> FolderTree {
        var count = 0
        return try await tree(of: folder, level: 1, count: &count, names: names)
    }

    private func tree(
        of folder: FileItem, level: Int, count: inout Int,
        names: @Sendable (FileItem) async -> FolderNameSettings?
    ) async throws -> FolderTree {
        guard level <= FolderTree.mostLevels else { throw FolderTree.Problem.tooDeep }
        count += 1
        guard count <= FolderTree.mostFolders else { throw FolderTree.Problem.tooManyFolders }
        var folders: [FolderTree] = []
        for item in try await contents(of: folder.id) where FolderTree.keeps(item) {
            try Task.checkCancellation()
            folders.append(
                try await tree(of: item, level: level + 1, count: &count, names: names))
        }
        return FolderTree(name: folder.name, folders: folders, names: await names(folder))
    }
}
