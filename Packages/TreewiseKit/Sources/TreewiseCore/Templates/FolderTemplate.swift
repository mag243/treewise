/// A folder structure template: a name and the tree of folders it makes, which may hold
/// `{year}` (ADR 0091).
public struct FolderTemplate: Codable, Hashable, Sendable {
    /// The name the user gave it, as listed in New Folders from Template.
    public var name: String
    /// The folders it makes, its root made in the folder chosen.
    public var root: FolderTree

    /// A template of `root` named `name`.
    public init(name: String, root: FolderTree) {
        self.name = name
        self.root = root
    }

    /// Whether making it asks for a year.
    public var hasYear: Bool { root.hasYear }
}
