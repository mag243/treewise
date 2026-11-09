#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Extracts an archive into a hidden workspace, and moves the result into
    /// place only when tar finished without an error (ADR 0074).
    /// The system's tar itself gives extracted items the archive's quarantine.
    enum ArchiveExtractor {
        /// Without a passphrase tar asks for one on the terminal, again and
        /// again. With this one, an archive that needs a password just fails.
        private static let placeholderPassphrase = "treewise-no-passphrase"
        private static let isoExtension = "iso"
        private static let outputName = "output"

        /// Extracts `archive` to `destination`, which must not exist yet.
        ///
        /// Postcondition: all of the archive is at `destination`, or nothing new is.
        static func extract(
            _ archive: URL, to destination: URL, onProgress: ArchiveProgressHandler,
            control: TransferControl
        ) throws {
            let folder = destination.deletingLastPathComponent()
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw FileSystemError.alreadyExists(FileItem.ID(destination.path))
            }
            let workspace = try ArchiveWorkspace(in: folder)
            defer { workspace.discard() }
            let output = workspace.url.appendingPathComponent(outputName)
            try createFolder(output, in: folder)
            let total = try countEntries(of: archive, in: workspace, control: control)
            var completed = 0
            let outcome = try TarProcess.run(
                ["--passphrase", placeholderPassphrase, "-xvf", archive.path, "-C", output.path],
                temporaryFolder: workspace.url, control: control
            ) { line in
                guard TarProcess.isEntry(line), !TarProcess.isFailure(line) else { return }
                completed += 1
                onProgress(
                    ArchiveProgress(
                        completedEntries: completed, totalEntries: total,
                        currentName: TarProcess.entryName(line)))
            }
            guard outcome.succeeded else { throw error(outcome, archive: archive, folder: folder) }
            if archive.pathExtension.lowercased() == isoExtension {
                ArchiveWorkspace.grantWrite(under: output, toFiles: true)
            }
            do {
                try FileManager.default.moveItem(at: output, to: destination)
            } catch {
                throw TrashService.error(error, for: FileItem.ID(destination.path))
            }
        }

        /// Lists the archive, which also finds an unknown format before
        /// anything is extracted.
        private static func countEntries(
            of archive: URL, in workspace: ArchiveWorkspace, control: TransferControl
        ) throws -> Int {
            var count = 0
            let outcome = try TarProcess.run(
                ["--passphrase", placeholderPassphrase, "-tf", archive.path],
                temporaryFolder: workspace.url, control: control
            ) { line in
                if !TarProcess.isFailure(line) { count += 1 }
            }
            guard outcome.succeeded else {
                throw error(outcome, archive: archive, folder: workspace.url)
            }
            return count
        }

        private static func createFolder(_ url: URL, in folder: URL) throws {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            } catch {
                throw TrashService.error(error, for: FileItem.ID(folder.path))
            }
        }

        private static func error(
            _ outcome: TarProcess.Outcome, archive: URL, folder: URL
        ) -> FileSystemError {
            TarFailure.extractionError(
                outcome.failures, archive: FileItem.ID(archive.path),
                folder: FileItem.ID(folder.path))
        }
    }
#endif
