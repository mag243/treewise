/// The folders of the year before that a year's folder lacks (ADR 0102): the tree of the
/// folder a year before, filled in for this year, against what this year's folder holds.
/// Names are compared as the file system compares them, without case.
public struct MissingFolders: Hashable, Sendable {
    /// The missing folders whose folder above is there, by their path below the year's
    /// folder; the folders in a missing folder come along with it and are not listed.
    public let paths: [[String]]
    /// The year's folder with only the missing folders and the folders they are in, each
    /// folder there under the name it has on disk, for the sheet that makes them.
    public let tree: FolderTree

    /// The folders of `made` that a folder holding `contents` lacks, `made`'s root being that
    /// folder, except those at the paths of `closed`.
    public init(
        of made: FolderTree, in contents: FolderContents, leavingOut closed: Set<[String]> = []
    ) {
        let closedKeys = Set(closed.map(Self.key))
        var paths: [[String]] = []
        let folders = Self.missing(
            below: made, in: contents, at: [], closed: closedKeys, into: &paths)
        self.paths = paths
        tree = FolderTree(name: made.name, folders: folders, names: made.names)
    }

    /// Whether no folder is missing.
    public var isEmpty: Bool { paths.isEmpty }

    /// The path as the file system compares it.
    static func key(_ path: [String]) -> [String] {
        path.map(ConflictResolver.comparisonKey)
    }

    private static func missing(
        below tree: FolderTree, in contents: FolderContents, at path: [String],
        closed: Set<[String]>, into paths: inout [[String]]
    ) -> [FolderTree] {
        tree.folders.compactMap { folder in
            if let there = contents.folder(named: folder.name) {
                let below = missing(
                    below: folder, in: there.contents, at: path + [there.name], closed: closed,
                    into: &paths)
                guard !below.isEmpty else { return nil }
                return FolderTree(name: there.name, folders: below, names: folder.names)
            }
            let found = path + [folder.name]
            guard !contents.holdsOther(named: folder.name), !closed.contains(key(found)) else {
                return nil
            }
            paths.append(found)
            return folder
        }
    }
}

extension FolderTree {
    /// This template with the folders of `recognized`, the folder a year before as the add-on
    /// recognized it, that it lacks and that make one of `missing`'s folders or a folder they
    /// are in, filled in with `values`; nil when it lacks none of them (ADR 0102). A folder
    /// added keeps its fields, the folders in it and its name settings.
    public func adding(
        _ missing: MissingFolders, from recognized: FolderTree, values: FolderTemplateValues
    ) -> FolderTree? {
        let wanted = missing.paths.map(MissingFolders.key)
        let (tree, added) = adding(lacking: recognized, below: [[]], values: values) { path in
            let key = MissingFolders.key(path)
            return wanted.contains { key.starts(with: $0) || $0.starts(with: key) }
        }
        return added > 0 ? tree : nil
    }

    private func adding(
        lacking recognized: FolderTree, below parents: [[String]], values: FolderTemplateValues,
        wanted: ([String]) -> Bool
    ) -> (tree: FolderTree, added: Int) {
        var folders = self.folders
        var added = 0
        for folder in recognized.folders {
            let made = folder.made(with: values).map(\.name)
            let paths = parents.flatMap { parent in made.map { parent + [$0] } }
            if let index = folders.firstIndex(where: { Self.isSame($0.name, folder.name) }) {
                let changed = folders[index].adding(
                    lacking: folder, below: paths, values: values, wanted: wanted)
                folders[index] = changed.tree
                added += changed.added
            } else if paths.contains(where: wanted) {
                folders.append(folder)
                added += 1
            }
        }
        return (FolderTree(name: name, folders: folders, names: names), added)
    }
}
