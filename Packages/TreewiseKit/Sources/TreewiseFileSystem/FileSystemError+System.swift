import Foundation
import TreewiseCore

extension FileSystemError {
    /// What a system error about `id` means for Treewise: a `FileSystemError` when it has a
    /// case of its own, else the error as it is. One mapping for reading, copying, the
    /// Trash and archives.
    static func mapping(_ error: any Error, for id: FileItem.ID) -> any Error {
        if let posix = error as? POSIXError { return mapping(posix, for: id) }
        guard let cocoa = error as? CocoaError else { return error }
        switch cocoa.code {
        case .fileNoSuchFile, .fileReadNoSuchFile: return FileSystemError.notFound(id)
        case .fileReadNoPermission: return FileSystemError.notReadable(id)
        case .fileWriteFileExists: return FileSystemError.alreadyExists(id)
        case .fileWriteNoPermission, .fileWriteVolumeReadOnly:
            return FileSystemError.notWritable(id)
        case .featureUnsupported: return FileSystemError.trashUnavailable(id)
        case .fileWriteOutOfSpace: return FileSystemError.notEnoughSpace(id)
        default: return error
        }
    }

    /// The errors `copyfile(3)` meets (ADR 0026).
    private static func mapping(_ error: POSIXError, for id: FileItem.ID) -> any Error {
        switch error.code {
        case .ENOENT: FileSystemError.notFound(id)
        case .EEXIST: FileSystemError.alreadyExists(id)
        case .EACCES, .EPERM, .EROFS: FileSystemError.notWritable(id)
        case .ENOSPC: FileSystemError.notEnoughSpace(id)
        case .ECANCELED: FileSystemError.cancelled
        default: error
        }
    }
}
