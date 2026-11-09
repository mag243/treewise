import Foundation

/// One entry of an archive, as its listing names it (ADR 0076).
public struct ArchiveEntry: Hashable, Sendable {
    /// The name as the archive stores it, which is what `tar` is asked for.
    public var storedName: String
    /// Whether the entry is a folder.
    public var isFolder: Bool
    /// The size in bytes as the archive lists it.
    public var size: Int64
    /// When the entry last changed, if listed.
    public var modified: Date?
    /// Whether `modified` holds a time; an older entry is listed by its day alone.
    public var modifiedHasTime: Bool

    /// Creates an entry.
    public init(
        storedName: String, isFolder: Bool, size: Int64, modified: Date?,
        modifiedHasTime: Bool = true
    ) {
        self.storedName = storedName
        self.isFolder = isFolder
        self.size = size
        self.modified = modified
        self.modifiedHasTime = modifiedHasTime
    }
}
