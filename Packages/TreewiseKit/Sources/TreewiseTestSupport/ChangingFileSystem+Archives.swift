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
