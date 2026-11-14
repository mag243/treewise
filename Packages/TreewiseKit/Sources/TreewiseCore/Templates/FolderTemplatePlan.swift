/// The folders a tree makes in a folder, beside what the folder holds (ADR 0091): a folder
/// already there is kept and filled under the name it has, a file with a folder's name leaves
/// that folder out with those below it, and nothing is replaced or moved.
public struct FolderTemplatePlan: Hashable, Sendable {
    /// What becomes of a folder of the tree.
    public enum State: Hashable, Sendable {
        /// It is made.
        case new
        /// It is there already and kept.
        case existing
        /// An item that is no folder has its name; it is not made, nor those below it.
        case leftOut
    }

    /// A folder of the tree, by its path below the folder the tree is made in.
    public struct Entry: Hashable, Sendable {
        /// The names from the tree's root down to the folder, as the disk names those there.
        public let path: [String]
        /// What becomes of it.
        public let state: State
    }

    /// Every folder of the tree, each before the folders in it, in the tree's order. Below a
    /// folder left out, nothing is listed.
    public let entries: [Entry]

    /// The plan for making `tree` in a folder that holds `contents`.
    public init(making tree: FolderTree, in contents: FolderContents) {
        var entries: [Entry] = []
        Self.plan(tree, in: contents, below: [], into: &entries)
        self.entries = entries
    }

    /// The folders to make, each after the folder it is made in.
    public var toMake: [[String]] { entries.filter { $0.state == .new }.map(\.path) }

    /// The folders left out because an item that is no folder has their name.
    public var leftOut: [[String]] { entries.filter { $0.state == .leftOut }.map(\.path) }

    private static func plan(
        _ tree: FolderTree, in contents: FolderContents?, below parent: [String],
        into entries: inout [Entry]
    ) {
        if let contents, let there = contents.folder(named: tree.name) {
            let path = parent + [there.name]
            entries.append(Entry(path: path, state: .existing))
            for folder in tree.folders {
                plan(folder, in: there.contents, below: path, into: &entries)
            }
        } else if let contents, contents.holdsOther(named: tree.name) {
            entries.append(Entry(path: parent + [tree.name], state: .leftOut))
        } else {
            let path = parent + [tree.name]
            entries.append(Entry(path: path, state: .new))
            for folder in tree.folders {
                plan(folder, in: nil, below: path, into: &entries)
            }
        }
    }
}
