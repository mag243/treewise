/// What making a template's folders did (ADR 0091).
public struct FolderTemplateOutcome: Sendable {
    /// The change, whose undo puts the folders made in the Trash: one step for Undo.
    public let result: OperationResult
    /// How many folders were made.
    public let madeCount: Int
    /// The folders left out because an item that is no folder has their name, by their path
    /// below the folder the tree was made in.
    public let leftOut: [[String]]
    /// The folders made, by their path below the folder the tree was made in, the tree's
    /// root first, for giving them their name settings (ADR 0101).
    public let made: [[String]: FileItem.ID]
}

extension FileSystemProviding {
    /// What a folder holds along `tree`: its items, and those of each folder the tree goes
    /// into, as far as the tree goes. Hidden folders count as folders, as they are on disk.
    public func folderContents(for tree: FolderTree, in folder: FileItem.ID) async throws
        -> FolderContents
    {
        let items = try await contents(of: folder)
        var folders: [String: FolderContents] = [:]
        var files: Set<String> = []
        for item in items {
            guard item.kind == .folder else {
                files.insert(item.name)
                continue
            }
            let below = tree.folders.first {
                ConflictResolver.comparisonKey($0.name) == ConflictResolver.comparisonKey(item.name)
            }
            if let below {
                folders[item.name] = try await folderContents(for: below, in: item.id)
            } else {
                folders[item.name] = FolderContents()
            }
        }
        return FolderContents(folders: folders, files: files)
    }
}

extension FileOperating {
    /// Makes the folders of `tree` that `folder` lacks, its root among them, as
    /// `FolderTemplatePlan` plans them against what is there now: nothing is replaced or
    /// moved. Undo puts every folder made in the Trash, as one step.
    ///
    /// Precondition: `tree` has passed `FolderTree.check()`.
    public func createFolders(making tree: FolderTree, in folder: FileItem.ID) async throws
        -> FolderTemplateOutcome
    {
        let there = try await folderContents(for: FolderTree(name: "", folders: [tree]), in: folder)
        let plan = FolderTemplatePlan(making: tree, in: there)
        var ids: [[String]: FileItem.ID] = [[]: folder]
        var topmost: [FileItem] = []
        var made: [[String]: FileItem.ID] = [:]
        for entry in plan.entries {
            let parentPath = Array(entry.path.dropLast())
            guard let parent = ids[parentPath], let name = entry.path.last else { continue }
            switch entry.state {
            case .new:
                try Task.checkCancellation()
                let folder = try await createFolder(in: parent, named: name)
                ids[entry.path] = folder.id
                made[entry.path] = folder.id
                if !plan.isNew(parentPath) { topmost.append(folder) }
            case .existing:
                ids[entry.path] = try await contents(of: parent).first {
                    $0.kind == .folder && $0.name == name
                }?.id
            case .leftOut:
                continue
            }
        }
        return FolderTemplateOutcome(
            result: OperationResult(items: topmost, undo: .trash(topmost.map(\.id))),
            madeCount: made.count, leftOut: plan.leftOut, made: made)
    }
}

extension FolderTemplatePlan {
    /// Whether the folder at `path` is one the plan makes.
    func isNew(_ path: [String]) -> Bool {
        entries.contains { $0.path == path && $0.state == .new }
    }
}
