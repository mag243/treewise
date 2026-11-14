/// What a folder holds, as far as making a template in it cares: its folders with what they
/// hold, and the names of everything else (ADR 0091).
public struct FolderContents: Sendable {
    /// Each folder by the form of its name the file system compares, with its name and contents.
    private let folders: [String: (name: String, contents: FolderContents)]
    /// The compared forms of the names of the files, packages and aliases.
    private let others: Set<String>

    /// A folder holding `folders` and items of other kinds named `files`.
    public init(folders: [String: FolderContents] = [:], files: Set<String> = []) {
        self.folders = Dictionary(
            folders.map {
                (ConflictResolver.comparisonKey($0.key), (name: $0.key, contents: $0.value))
            },
            uniquingKeysWith: { first, _ in first })
        others = Set(files.map(ConflictResolver.comparisonKey))
    }

    /// The folder the file system would take for `name`, with the name it has, or nil.
    func folder(named name: String) -> (name: String, contents: FolderContents)? {
        folders[ConflictResolver.comparisonKey(name)]
    }

    /// Whether an item that is no folder has a name the file system takes for `name`.
    func holdsOther(named name: String) -> Bool {
        others.contains(ConflictResolver.comparisonKey(name))
    }
}
