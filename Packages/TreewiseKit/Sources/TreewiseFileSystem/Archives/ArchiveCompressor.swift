#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Compresses items in a hidden workspace, and moves the archive into place
    /// only when tar finished without an error (ADR 0074).
    enum ArchiveCompressor {
        /// What keeps a zip or 7z clean for other systems: no `__MACOSX`, `._`
        /// files, `.DS_Store` or extended attributes.
        private static let cleanOptions = [
            "--no-mac-metadata", "--no-xattrs", "--no-fflags", "--exclude", ".DS_Store",
            "--exclude",
            "._*", "--exclude", "__MACOSX",
        ]
        private static let archiveName = "archive"
        private static let namesFileName = "names"

        /// Compresses `items`, which share a parent folder, to `destination`,
        /// which must not exist yet.
        ///
        /// Postcondition: the complete archive is at `destination`, or nothing new is.
        static func compress(
            _ items: [URL], to destination: URL, format: ArchiveFormat,
            onProgress: ArchiveProgressHandler, control: TransferControl
        ) throws {
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw FileSystemError.alreadyExists(FileItem.ID(destination.path))
            }
            let folder = destination.deletingLastPathComponent()
            let workspace = try ArchiveWorkspace(in: folder)
            defer { workspace.discard() }
            let archive = workspace.url.appendingPathComponent(archiveName)
            let names = workspace.url.appendingPathComponent(namesFileName)
            try Data(items.map { $0.lastPathComponent + "\0" }.joined().utf8).write(to: names)
            let total = items.reduce(0) { $0 + entryCount(of: $1) }
            var completed = 0
            let outcome = try TarProcess.run(
                options(for: format) + [
                    "-cvf", archive.path, "-C", items[0].deletingLastPathComponent().path, "--null",
                    "-T", names.path,
                ],
                temporaryFolder: workspace.url, control: control
            ) { line in
                guard TarProcess.isEntry(line), !TarProcess.isFailure(line) else { return }
                completed += 1
                onProgress(
                    ArchiveProgress(
                        completedEntries: completed, totalEntries: total,
                        currentName: TarProcess.entryName(line)))
            }
            guard outcome.succeeded else {
                throw TarFailure.compressionError(
                    outcome.failures, folder: FileItem.ID(folder.path))
            }
            do {
                try FileManager.default.moveItem(at: archive, to: destination)
            } catch {
                throw TrashService.error(error, for: FileItem.ID(destination.path))
            }
        }

        private static func options(for format: ArchiveFormat) -> [String] {
            switch format {
            case .zip: ["--format", "zip"] + cleanOptions
            case .sevenZip: ["--format", "7zip"] + cleanOptions
            case .tarGzip: ["-z"]
            }
        }

        /// The number of entries an item adds: itself and all it holds.
        private static func entryCount(of item: URL) -> Int {
            var count = 1
            let entries = FileManager.default.enumerator(
                at: item, includingPropertiesForKeys: nil)
            while entries?.nextObject() != nil { count += 1 }
            return count
        }
    }
#endif
