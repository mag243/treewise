#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Compresses items in a hidden workspace, and moves the archive into place
    /// only when tar finished without an error (ADR 0074).
    enum ArchiveCompressor {
        /// What keeps a zip or 7z clean for other systems: no `__MACOSX`, `._`
        /// files, `.DS_Store` or extended attributes.
        private static let cleanOptions =
            MacMetadata.tarOptions + MacMetadata.excludedNames.flatMap { ["--exclude", $0] }
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
            let isClean = format != .tarGzip
            let total = items.reduce(0) { $0 + entryCount(of: $1, skippingLeftovers: isClean) }
            var counter = TarProcess.EntryCounter(total: total)
            let outcome = try TarProcess.run(
                options(for: format) + [
                    "-cvf", archive.path, "-C", items[0].deletingLastPathComponent().path, "--null",
                    "-T", names.path,
                ],
                temporaryFolder: workspace.url, control: control
            ) { line in
                if let progress = counter.read(line) { onProgress(progress) }
            }
            guard outcome.succeeded else {
                throw TarFailure.compressionError(
                    outcome.failures, folder: FileItem.ID(folder.path))
            }
            do {
                try FileManager.default.moveItem(at: archive, to: destination)
            } catch {
                throw FileSystemError.mapping(error, for: FileItem.ID(destination.path))
            }
        }

        private static func options(for format: ArchiveFormat) -> [String] {
            switch format {
            case .zip: ["--format", "zip"] + cleanOptions
            case .sevenZip: ["--format", "7zip"] + cleanOptions
            case .tarGzip: ["-z"]
            }
        }

        /// The number of entries an item adds: itself and all it holds, without
        /// what `cleanOptions` leaves out when `skippingLeftovers` is set.
        private static func entryCount(of item: URL, skippingLeftovers: Bool) -> Int {
            if skippingLeftovers, MacMetadata.isLeftover(item.lastPathComponent) { return 0 }
            var count = 1
            let entries = FileManager.default.enumerator(at: item, includingPropertiesForKeys: nil)
            while let entry = entries?.nextObject() as? URL {
                if skippingLeftovers, MacMetadata.isLeftover(entry.lastPathComponent) {
                    entries?.skipDescendants()
                } else {
                    count += 1
                }
            }
            return count
        }

    }
#endif
