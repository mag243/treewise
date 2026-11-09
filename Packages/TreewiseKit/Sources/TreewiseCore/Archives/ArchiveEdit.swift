import Foundation

/// A file or folder on disk that goes into an archive (ADR 0078).
public struct ArchiveAddition: Hashable, Sendable {
    /// Where it is on disk now.
    public var source: URL
    /// Where it goes inside the archive.
    public var path: String

    /// Creates an addition.
    public init(source: URL, path: String) {
        self.source = source
        self.path = path
    }
}

/// A kept version of an archive, for undo and redo (ADR 0078).
public struct ArchiveVersion: Hashable, Sendable {
    /// The archive it is a version of.
    public var archive: FileItem.ID
    /// Where the version is kept.
    public var file: FileItem.ID
    /// What tells the archive as this change left it, to see that it is
    /// still so when undoing.
    public var signature: String

    /// Creates a version.
    public init(archive: FileItem.ID, file: FileItem.ID, signature: String) {
        self.archive = archive
        self.file = file
        self.signature = signature
    }
}

/// What the user changes in an archive, in paths inside it (ADR 0078).
public enum ArchiveEdit: Hashable, Sendable {
    /// These go in, replacing what has the same path.
    case add([ArchiveAddition])
    /// These go, with everything below them.
    case remove([String])
    /// A file or folder gets another path, with everything below it.
    case relocate(from: String, to: String)
    /// An empty folder at this path.
    case newFolder(String)
}
