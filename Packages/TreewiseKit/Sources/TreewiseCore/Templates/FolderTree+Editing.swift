/// Editing a template's tree, as Settings' Templates tab does (ADR 0095). A folder is found by
/// its path: the names from below the root down to it, so the root's path is empty. Each
/// edit returns the tree changed and checked as a template, and the path of the folder it
/// changed; a change the tree cannot take throws and changes nothing.
extension FolderTree {
    /// The folder at `path`, or nil when there is none.
    public func folder(at path: [String]) -> FolderTree? {
        guard let first = path.first else { return self }
        return folders.first { $0.name == first }?.folder(at: Array(path.dropFirst()))
    }

    /// The tree with a new folder in the one at `path`, named `name`, or `name 2`, `name 3`,
    /// … when that is taken.
    /// - Precondition: there is a folder at `path`.
    public func adding(in path: [String], named name: String) throws(Problem)
        -> (tree: FolderTree, path: [String])
    {
        guard let parent = folder(at: path) else {
            preconditionFailure("A folder is added in a folder of the tree.")
        }
        var unique = name
        var number = 2
        while parent.holdsFolder(named: unique) {
            unique = "\(name) \(number)"
            number += 1
        }
        let edited = replacing(at: path) {
            FolderTree(
                name: $0.name, folders: $0.folders + [FolderTree(name: unique)], names: $0.names)
        }
        try edited.checkTemplate()
        return (edited, path + [unique])
    }

    /// The tree with the folder at `path` named `name`, which no other folder beside it has.
    /// - Precondition: there is a folder at `path`.
    public func renaming(_ path: [String], to name: String) throws(Problem)
        -> (tree: FolderTree, path: [String])
    {
        precondition(folder(at: path) != nil, "A folder of the tree is renamed.")
        if let last = path.last, let parent = folder(at: path.dropLast()),
            parent.folders.contains(where: { $0.name != last && Self.isSame($0.name, name) })
        {
            throw .sameName(name)
        }
        let edited = replacing(at: path) {
            FolderTree(name: name, folders: $0.folders, names: $0.names)
        }
        try edited.checkTemplate()
        return (edited, path.isEmpty ? [] : path.dropLast() + [name])
    }

    /// The tree without the folder at `path` and the folders in it.
    /// - Precondition: `path` names a folder below the root.
    public func removing(_ path: [String]) -> FolderTree {
        precondition(!path.isEmpty && folder(at: path) != nil, "A folder below the root goes.")
        return replacing(at: path) { _ in nil }
    }

    /// The tree with the folder at `path` moved into the one at `target`, never into itself
    /// or a folder in it.
    /// - Precondition: `path` names a folder below the root, and `target` a folder.
    public func moving(_ path: [String], into target: [String]) throws(Problem)
        -> (tree: FolderTree, path: [String])
    {
        guard let moved = folder(at: path), !path.isEmpty, let destination = folder(at: target)
        else { preconditionFailure("A folder below the root moves into a folder of the tree.") }
        guard !target.starts(with: path) else { throw .intoItself }
        guard Array(path.dropLast()) != target else { return (self, path) }
        guard !destination.holdsFolder(named: moved.name) else { throw .sameName(moved.name) }
        let edited = removing(path).replacing(at: target) {
            FolderTree(name: $0.name, folders: $0.folders + [moved], names: $0.names)
        }
        try edited.checkTemplate()
        return (edited, target + [moved.name])
    }

    /// The tree without the name settings of the folder at `path` (ADR 0101).
    public func removingNames(at path: [String]) -> FolderTree {
        replacing(at: path) { FolderTree(name: $0.name, folders: $0.folders) }
    }

    /// The name settings of each folder that has them, by its path from the root, the root's
    /// name first, as the folders made are found (ADR 0101).
    public var namesByPath: [[String]: FolderNameSettings] {
        var found: [[String]: FolderNameSettings] = [:]
        collectNames(above: [], into: &found)
        return found
    }

    private func collectNames(above: [String], into found: inout [[String]: FolderNameSettings]) {
        let path = above + [name]
        if let names { found[path] = names }
        for folder in folders { folder.collectNames(above: path, into: &found) }
    }

    private func holdsFolder(named name: String) -> Bool {
        folders.contains { Self.isSame($0.name, name) }
    }

    private static func isSame(_ one: String, _ other: String) -> Bool {
        ConflictResolver.comparisonKey(one) == ConflictResolver.comparisonKey(other)
    }

    /// The tree with the folder at `path` replaced by `change` of it, or left out when that
    /// gives nil. A path that names no folder leaves the tree as it is.
    private func replacing<Path: Collection<String>>(
        at path: Path, with change: (FolderTree) -> FolderTree?
    ) -> FolderTree {
        guard let first = path.first else { return change(self) ?? self }
        let rest = path.dropFirst()
        let changed: [FolderTree] = folders.compactMap { folder in
            guard folder.name == first else { return folder }
            return rest.isEmpty ? change(folder) : folder.replacing(at: rest, with: change)
        }
        return FolderTree(name: name, folders: changed, names: names)
    }

    private func folder<Path: Collection<String>>(at path: Path) -> FolderTree? {
        folder(at: Array(path))
    }
}
