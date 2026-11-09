/// A place inside an archive (ADR 0076). As an identifier it is the archive's
/// path, then `//`, then the path inside the archive. A standardized path never
/// holds `//`, so the string alone tells that an item is inside an archive. A
/// path that was not standardized can hold `//` too, so the part before it must
/// have an archive's name and the part after it must be a clean path.
///
/// This is the only code that reads or writes that form.
///
/// Invariant: `archive` is outside an archive, and `entry` has no leading or
/// trailing slash.
public struct ArchivePath: Hashable, Sendable {
    private static let separator = "//"
    private static let slash: Character = "/"

    /// The archive on disk.
    public let archive: FileItem.ID
    /// The path inside the archive, empty for its top level.
    public let entry: String

    /// Creates a place in an archive, by default its top level.
    ///
    /// Precondition: `archive` is outside an archive, and `entry` has no
    /// leading or trailing slash.
    public init(archive: FileItem.ID, entry: String = "") {
        precondition(!archive.isInsideArchive, "archive is outside an archive")
        precondition(
            entry.first != Self.slash && entry.last != Self.slash,
            "entry has no leading or trailing slash")
        self.archive = archive
        self.entry = entry
    }

    /// Reads a place from an identifier, or returns `nil` for one outside an archive.
    public init?(_ id: FileItem.ID) {
        guard let separator = id.rawValue.firstRange(of: Self.separator) else { return nil }
        let archivePath = String(id.rawValue[..<separator.lowerBound])
        let entry = String(id.rawValue[separator.upperBound...])
        guard ArchiveNaming.isArchive(name: Self.lastPart(of: archivePath), kind: .file),
            entry.first != Self.slash, entry.last != Self.slash,
            entry.firstRange(of: Self.separator) == nil
        else { return nil }
        archive = FileItem.ID(archivePath)
        self.entry = entry
    }

    /// The place as an identifier.
    public var id: FileItem.ID {
        FileItem.ID(archive.rawValue + Self.separator + entry)
    }

    /// Whether the archive's format can be changed (ADR 0078).
    public var isChangeable: Bool {
        ArchiveNaming.canChange(name: Self.lastPart(of: archive.rawValue))
    }

    /// Whether this is the archive's top level.
    public var isTopLevel: Bool { entry.isEmpty }

    /// The name the place shows: the last part of its entry, or the archive's name.
    public var name: String {
        Self.lastPart(of: isTopLevel ? archive.rawValue : entry)
    }

    /// What contains the place: a folder in the archive, the top level, or the
    /// folder on disk that holds the archive.
    public var parent: FileItem.ID {
        guard !isTopLevel else {
            let folder = Self.withoutLastPart(of: archive.rawValue)
            return FileItem.ID(folder.isEmpty ? String(Self.slash) : folder)
        }
        return ArchivePath(archive: archive, entry: Self.withoutLastPart(of: entry)).id
    }

    /// The volume of everything in this archive, of its own, so that no rule
    /// takes an entry for an item on the archive's disk.
    public var volume: VolumeID {
        VolumeID("archive:" + archive.rawValue)
    }

    /// The place of an item directly inside this one.
    public func child(_ name: String) -> ArchivePath {
        ArchivePath(archive: archive, entry: isTopLevel ? name : entry + String(Self.slash) + name)
    }

    private static func lastPart(of path: String) -> String {
        path.lastIndex(of: slash).map { String(path[path.index(after: $0)...]) } ?? path
    }

    private static func withoutLastPart(of path: String) -> String {
        path.lastIndex(of: slash).map { String(path[..<$0]) } ?? ""
    }
}

extension FileItem.ID {
    /// The path as people read it: inside an archive with a single slash.
    public var shownPath: String {
        guard let place = ArchivePath(self) else { return rawValue }
        return place.isTopLevel
            ? place.archive.rawValue : place.archive.rawValue + "/" + place.entry
    }

    /// Whether the identifier is of a place inside an archive (ADR 0076).
    public var isInsideArchive: Bool {
        ArchivePath(self) != nil
    }
}
