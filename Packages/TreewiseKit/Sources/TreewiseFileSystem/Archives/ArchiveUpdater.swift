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
            _ job: Job, onProgress: ArchiveProgressHandler, control: TransferControl
        ) throws {
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
                try replace(job, with: candidate)
                return
            }
            guard !control.isStopped else { throw FileSystemError.cancelled }
            ArchiveWorkspace.remove(candidate)
            try run.updateWithTar(candidate, onProgress: onProgress)
            guard try isExpected(candidate, run, control) else {
                throw FileSystemError.archiveDamaged(job.archive)
            }
            try replace(job, with: candidate)
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

        private static func replace(_ job: Job, with candidate: URL) throws {
            do {
                try FileCoordination.write(job.url) {
                    _ = try FileManager.default.replaceItemAt($0, withItemAt: candidate)
                }
            } catch {
                throw TrashService.error(error, for: job.archive)
            }
        }
    }
#endif
