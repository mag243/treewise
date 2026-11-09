import Foundation
import TreewiseCore

/// The way from an identifier to a file on disk (ADR 0076). The app goes
/// through these, so that no action reaches for a path inside an archive,
/// where no file exists.
extension FileItem.ID {
    /// The item's path on disk, or `nil` inside an archive.
    public var diskPath: String? {
        isInsideArchive ? nil : rawValue
    }

    /// The item's file on disk, or `nil` inside an archive.
    public var diskURL: URL? {
        diskPath.map { URL(fileURLWithPath: $0) }
    }

    /// The file Finder shows for the item: the item, or the archive that holds it.
    public var urlShownInFinder: URL {
        URL(fileURLWithPath: ArchivePath(self)?.archive.rawValue ?? rawValue)
    }
}
