import Foundation
import TreewiseCore

/// An archive engine without archives: an extraction makes an empty folder, a
/// compression an empty file. Both wait while changes are held, and report one
/// entry of two.
extension ChangingFileSystem: ArchiveOperating {
    public func extract(
        _ archive: FileItem, into folder: FileItem.ID, as name: String,
        onProgress: @escaping ArchiveProgressHandler, control: TransferControl
    ) async throws -> FileItem {
        try await prepare(onProgress: onProgress, control: control)
        return try await createFolder(in: folder, named: name)
    }

    public func cachedCopy(of item: FileItem) async throws -> URL {
        try throwFailureIfSet()
        return URL(fileURLWithPath: "/cache/" + item.name)
    }

    @discardableResult
    public func apply(
        _ edit: ArchiveEdit, to archive: FileItem.ID,
        onProgress: @escaping ArchiveProgressHandler, control: TransferControl
    ) async throws -> UndoRecord {
        try await prepare(onProgress: onProgress, control: control)
        return .none
    }

    public func restore(_ version: ArchiveVersion) async throws -> ArchiveVersion {
        version
    }

    public func writeEntry(_ entry: FileItem, toPromisedFile file: URL) async throws {
        let folder = FileItem.ID(file.deletingLastPathComponent().standardizedFileURL.path)
        _ = try await copy(entry, into: folder, as: file.lastPathComponent)
    }

    public func releaseCache(of archive: FileItem.ID) async {
        recordRelease(of: archive)
    }

    /// Whether `archive` is released soon, as a window does that in a task of its own.
    public func eventuallyReleased(_ archive: FileItem.ID) async -> Bool {
        for _ in 0..<Self.releaseChecks {
            if releasedArchives.contains(archive) { return true }
            await Task.yield()
        }
        return releasedArchives.contains(archive)
    }

    private static var releaseChecks: Int { 10_000 }

    public func compress(
        _ items: [FileItem], to archive: NewArchive,
        onProgress: @escaping ArchiveProgressHandler, control: TransferControl
    ) async throws -> FileItem {
        try await prepare(onProgress: onProgress, control: control)
        // A folder made through the protocol carries a failure set by a test;
        // it then becomes the file the archive is.
        let created = try await createFolder(in: archive.folder, named: archive.name)
        remove(created.id)
        let file = FileItem(
            id: created.id, name: archive.name, kind: .file, parentID: archive.folder,
            volume: created.volume)
        add(file)
        return file
    }

    private func prepare(
        onProgress: ArchiveProgressHandler, control: TransferControl
    ) async throws {
        try await waitWhileHeld()
        guard await control.untilResumed() else { throw FileSystemError.cancelled }
        onProgress(ArchiveProgress(completedEntries: 1, totalEntries: 2, currentName: "entry"))
    }
}
