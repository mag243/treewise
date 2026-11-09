/// Where a compression puts its archive, and in what format.
public struct NewArchive: Sendable, Hashable {
    /// The folder the archive goes into.
    public var folder: FileItem.ID
    /// The archive's full name, extension included.
    public var name: String
    /// The archive's format.
    public var format: ArchiveFormat

    /// Creates the description of a new archive.
    public init(folder: FileItem.ID, name: String, format: ArchiveFormat) {
        self.folder = folder
        self.name = name
        self.format = format
    }
}
