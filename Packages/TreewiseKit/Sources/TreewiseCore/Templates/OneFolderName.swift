/// One new name for folders in several places, as Rename in All Years gives the same folder
/// in every year's folder (ADR 0139). It knows nothing of years: the caller says which
/// folders, and what is beside each. Names compare as `ConflictResolver` compares them.
public struct OneFolderName: Hashable, Sendable {
    /// A folder to give the new name, with the names of the items beside it, its own too.
    public struct Place: Hashable, Sendable {
        /// The folder.
        public let folder: FileItem.ID
        /// The folder that holds it.
        public let parent: FileItem.ID
        /// The name it has now.
        public let name: String
        /// The names of every item in `parent`.
        public let namesBeside: [String]

        /// A folder named `name` in `parent`, beside items named `namesBeside`.
        public init(folder: FileItem.ID, parent: FileItem.ID, name: String, namesBeside: [String]) {
            self.folder = folder
            self.parent = parent
            self.name = name
            self.namesBeside = namesBeside
        }
    }

    /// What happens to one folder.
    public enum Outcome: Hashable, Sendable {
        /// It gets the new name; a name that differs only in case is corrected too.
        case renamed
        /// It has the new name already, exactly.
        case alreadyNamed
        /// Another item beside it has the new name, under this name on disk, so it is left
        /// out: merging two folders is not part of this.
        case besideFolderNamed(String)
    }

    /// A folder with what happens to it.
    public struct Entry: Hashable, Sendable {
        /// The folder.
        public let place: Place
        /// What happens to it.
        public let outcome: Outcome
    }

    /// The new name.
    public let newName: String
    /// Every folder, in the order given.
    public let entries: [Entry]

    /// The plan to give the folders at `places` the name `newName`.
    public init(_ places: [Place], to newName: String) {
        self.newName = newName
        let key = ConflictResolver.comparisonKey(newName)
        entries = places.map { place in
            if place.name == newName { return Entry(place: place, outcome: .alreadyNamed) }
            let other = place.namesBeside.first {
                $0 != place.name && ConflictResolver.comparisonKey($0) == key
            }
            return Entry(place: place, outcome: other.map { .besideFolderNamed($0) } ?? .renamed)
        }
    }

    /// The renames of the folders that get the new name, for `BatchRenamePlanner`.
    public var renames: [BatchRename] {
        entries.filter { $0.outcome == .renamed }.map {
            BatchRename(
                item: $0.place.folder, folder: $0.place.parent, from: $0.place.name, to: newName)
        }
    }
}

extension FolderTree {
    /// The tree with the folder at `path`, its names as the disk writes them, named `name`;
    /// nil when the tree holds no folder there or cannot take the name (ADR 0139). Names
    /// compare as the file system compares them.
    public func renamingFolder(atDiskPath path: [String], to name: String) -> FolderTree? {
        guard let own = ownPath(ofDiskPath: path) else { return nil }
        return try? renaming(own, to: name).tree
    }

    /// The path of the folder at `path` with the names the tree gives its folders.
    private func ownPath(ofDiskPath path: [String]) -> [String]? {
        guard let first = path.first else { return [] }
        guard let folder = folders.first(where: { Self.isSame($0.name, first) }),
            let rest = folder.ownPath(ofDiskPath: Array(path.dropFirst()))
        else { return nil }
        return [folder.name] + rest
    }
}

extension FolderSettings {
    /// The closed missing folders with the folder at `path` named `name`, those inside it
    /// too, so a folder closed under its old name stays closed (ADR 0102, ADR 0139).
    /// - Precondition: `path` names a folder below the year's folder.
    public mutating func renameClosedMissing(at path: [String], to name: String) {
        precondition(!path.isEmpty, "`path` names a folder below the year's folder.")
        let key = MissingFolders.key(path)
        missingFoldersClosed = Set(
            missingFoldersClosed.map { closed in
                guard closed.count >= path.count,
                    MissingFolders.key(Array(closed.prefix(path.count))) == key
                else { return closed }
                var renamed = closed
                renamed[path.count - 1] = name
                return renamed
            })
    }
}
