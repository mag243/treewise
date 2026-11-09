/// Why a file system provider could not answer or could not change something,
/// with the item it is about (ADR 0018).
public enum FileSystemError: Error, Hashable, Sendable {
    /// No item exists with this identity.
    case notFound(FileItem.ID)
    /// The item exists, but its contents may not be read.
    case notReadable(FileItem.ID)
    /// The item, or the folder it would go into, may not be changed.
    case notWritable(FileItem.ID)
    /// An item with this name is already in the folder.
    case alreadyExists(FileItem.ID)
    /// The name cannot be given to an item (`FolderNaming.isValidName`).
    case invalidName(String)
    /// The operation was cancelled; what was done before stays done.
    case cancelled
    /// A copy did not match its source, so the source was kept.
    case verificationFailed(FileItem.ID)
    /// The item's volume has no Trash.
    case trashUnavailable(FileItem.ID)
    /// The item is outside the folders the app is confined to (ADR 0019).
    case outsideBoundary(FileItem.ID)
    /// The target volume has too little free space for the item.
    case notEnoughSpace(FileItem.ID)
    /// The volume could not be ejected, with the system's reason (ADR 0044).
    case notEjected(FileItem.ID, String)
    /// The archive is damaged, or holds an entry that may not be extracted.
    case archiveDamaged(FileItem.ID)
    /// The archive is protected with a password (ADR 0074).
    case archivePasswordProtected(FileItem.ID)
    /// The file is not in a format the archive engine can read.
    case archiveFormatUnknown(FileItem.ID)
    /// Something would change an archive, which is read-only (ADR 0076).
    case archiveReadOnly
    /// A failure without a case of its own, with the system's description of it.
    case unexpected(String)
}
