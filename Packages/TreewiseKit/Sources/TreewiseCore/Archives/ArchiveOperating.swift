import Foundation

/// Called after each entry an archive operation handles.
public typealias ArchiveProgressHandler = @Sendable (ArchiveProgress) -> Void

/// Extracts and compresses archives (ADR 0074). The engine differs per platform.
public protocol ArchiveOperating: Sendable {
    /// Extracts an archive to a new folder `name` in `folder`.
    ///
    /// `control` pauses and stops it, a stop throwing `FileSystemError.cancelled`.
    ///
    /// Postcondition: either all of the archive is in the new folder, or
    /// nothing new exists.
    ///
    /// - Throws: `archiveDamaged`, `archivePasswordProtected` or
    ///   `archiveFormatUnknown` for the archive, `alreadyExists` when `name` is taken.
    func extract(
        _ archive: FileItem, into folder: FileItem.ID, as name: String,
        onProgress: @escaping ArchiveProgressHandler, control: TransferControl
    ) async throws -> FileItem

    /// A copy of an entry on disk, for Quick Look and opening a file, in a
    /// folder of Treewise's that `releaseCache` removes (ADR 0076).
    ///
    /// - Throws: `archivePasswordProtected` or `archiveDamaged` for the archive.
    func cachedCopy(of item: FileItem) async throws -> URL

    /// Removes the copies made from an archive.
    func releaseCache(of archive: FileItem.ID) async

    /// Compresses items of one folder to a new archive.
    ///
    /// `control` pauses and stops it, a stop throwing `FileSystemError.cancelled`.
    ///
    /// Precondition: `items` is not empty and its items share a parent folder.
    /// Postcondition: the complete archive exists, or nothing new exists.
    ///
    /// - Throws: `alreadyExists` when the archive's name is taken.
    func compress(
        _ items: [FileItem], to archive: NewArchive,
        onProgress: @escaping ArchiveProgressHandler, control: TransferControl
    ) async throws -> FileItem
}
