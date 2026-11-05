/// An approved rename of one item (ADR 0057).
public struct BatchRename: Hashable, Sendable {
    /// The item.
    public let item: FileItem.ID
    /// The folder that holds it.
    public let folder: FileItem.ID
    /// The name it has now.
    public let from: String
    /// The name it should get.
    public let to: String

    /// Creates a rename.
    public init(item: FileItem.ID, folder: FileItem.ID, from: String, to: String) {
        self.item = item
        self.folder = folder
        self.from = from
        self.to = to
    }
}
