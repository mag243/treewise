#if os(macOS)
    import Foundation
    import TreewiseCore
    import os

    /// Reads what an archive holds with the system's `tar` (ADR 0076).
    enum ArchiveLister {
        private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "archives")

        /// Lists `archive`. A listing that ends in an error is discarded as a whole.
        ///
        /// - Throws: `FileSystemError.archiveFormatUnknown`, `.archiveDamaged` or
        ///   `.archivePasswordProtected`; `.cancelled` when `control` stopped it.
        static func tree(of archive: URL, control: TransferControl) throws -> ArchiveTree {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let now = Date()
            var entries: [ArchiveEntry] = []
            var unread = 0
            let outcome = try TarProcess.run(
                ["--passphrase", ArchiveExtractor.placeholderPassphrase, "-tvf", archive.path],
                temporaryFolder: FileManager.default.temporaryDirectory, control: control
            ) { line in
                guard !TarProcess.isFailure(line) else { return }
                if let entry = ArchiveEntry(listingLine: line, now: now, calendar: calendar) {
                    entries.append(entry)
                } else {
                    unread += 1
                }
            }
            guard outcome.succeeded else {
                throw TarFailure.extractionError(
                    outcome.failures, archive: FileItem.ID(archive.path),
                    folder: FileItem.ID(archive.path))
            }
            if unread > 0 {
                logger.error("\(unread, privacy: .public) lines of a listing could not be read")
            }
            return ArchiveTree(entries: entries)
        }
    }
#endif
