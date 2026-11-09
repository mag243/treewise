#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Changes an archive by making a new one next to it, checking it and only
    /// then putting it in the old one's place (ADR 0078).
    enum ArchiveUpdater {
        /// What to change.
        struct Job: Sendable {
            var archive: FileItem.ID
            var edit: ArchiveEdit
            var tree: ArchiveTree

            var url: URL { URL(fileURLWithPath: archive.rawValue) }
        }

        private static let stagingName = "staging"
        private static let newArchiveName = "new"

        /// Applies `job`.
        ///
        /// Postcondition: the archive is changed as asked, or exactly as it was.
        static func apply(
            _ job: Job, versions: ArchiveVersions, onProgress: ArchiveProgressHandler,
            control: TransferControl
        ) throws -> UndoRecord {
            let workspace = try ArchiveWorkspace(in: job.url.deletingLastPathComponent())
            defer { workspace.discard() }
            try checkSpace(for: job)
            let run = try ArchiveUpdateRun(
                job: job, workspace: workspace, stagingName: stagingName, control: control)
            let candidate = workspace.url.appendingPathComponent(
                newArchiveName + "-" + job.url.lastPathComponent)
            if run.usesZip, (try? run.updateWithZip(candidate)) == true,
                try isExpected(candidate, run, control)
            {
                return try finish(job, candidate, workspace, versions)
            }
            guard !control.isStopped else { throw FileSystemError.cancelled }
            ArchiveWorkspace.remove(candidate)
            try run.updateWithTar(candidate, onProgress: onProgress)
            guard try isExpected(candidate, run, control) else {
                throw FileSystemError.archiveDamaged(job.archive)
            }
            return try finish(job, candidate, workspace, versions)
        }

        /// Puts a kept version of an archive back.
        ///
        /// - Returns: the version that redoes the change.
        static func restore(_ version: ArchiveVersion, versions: ArchiveVersions) throws
            -> ArchiveVersion
        {
            let archive = URL(fileURLWithPath: version.archive.rawValue)
            guard ArchiveSignature(path: archive.path)?.text == version.signature else {
                throw FileSystemError.archiveChangedSince(version.archive)
            }
            let workspace = try ArchiveWorkspace(in: archive.deletingLastPathComponent())
            defer { workspace.discard() }
            let redo = try versions.keep(archive, of: version.archive)
            let copy = workspace.url.appendingPathComponent(archive.lastPathComponent)
            try FileManager.default.copyItem(
                at: URL(fileURLWithPath: version.file.rawValue), to: copy)
            try replace(archive, id: version.archive, with: copy)
            return ArchiveVersion(
                archive: version.archive, file: FileItem.ID(redo.path),
                signature: ArchiveSignature(path: archive.path)?.text ?? "")
        }

        /// Keeps the old version and puts the new archive in its place.
        private static func finish(
            _ job: Job, _ candidate: URL, _ workspace: ArchiveWorkspace, _ versions: ArchiveVersions
        ) throws -> UndoRecord {
            let kept = try versions.keepCurrent(of: job.archive, in: workspace)
            try replace(job.url, id: job.archive, with: candidate)
            return .archiveVersion(
                ArchiveVersion(
                    archive: job.archive, file: FileItem.ID(kept.path),
                    signature: ArchiveSignature(path: job.url.path)?.text ?? ""))
        }

        private static func isExpected(
            _ candidate: URL, _ run: ArchiveUpdateRun, _ control: TransferControl
        ) throws -> Bool {
            do {
                return try ArchiveLister.tree(of: candidate, control: control)
                    .holdsExactly(run.expected)
            } catch FileSystemError.cancelled {
                throw FileSystemError.cancelled
            } catch {
                return false
            }
        }

        private static func checkSpace(for job: Job) throws {
            let folder = job.url.deletingLastPathComponent()
            let needed = try? job.url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            let free = try? folder.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey
            ]).volumeAvailableCapacityForImportantUsage
            if let needed, let free, Int64(needed) > free {
                throw FileSystemError.notEnoughSpace(FileItem.ID(folder.path))
            }
        }

        private static func replace(_ archive: URL, id: FileItem.ID, with candidate: URL) throws {
            do {
                try FileCoordination.write(archive) {
                    _ = try FileManager.default.replaceItemAt($0, withItemAt: candidate)
                }
            } catch {
                throw TrashService.error(error, for: id)
            }
        }
    }
#endif
