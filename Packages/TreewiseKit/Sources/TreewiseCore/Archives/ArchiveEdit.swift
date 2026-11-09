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

/// A file or folder that goes to another path inside its archive.
public struct ArchiveRelocation: Hashable, Sendable {
    /// Where it is.
    public var from: String
    /// Where it goes.
    public var to: String

    /// Creates a relocation.
    public init(from: String, to: String) {
        self.from = from
        self.to = to
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
    /// Files and folders get other paths, with everything below them. What
    /// already has such a path goes.
    case relocations([ArchiveRelocation])
    /// An empty folder at this path.
    case newFolder(String)

    /// One file or folder gets another path.
    public static func relocate(from source: String, to target: String) -> ArchiveEdit {
        .relocations([ArchiveRelocation(from: source, to: target)])
    }
}
