#if os(macOS)
    import Foundation
    import Synchronization
    import TreewiseCore

    /// Copies of entries of archives, for Quick Look and opening a file
    /// (ADR 0076). Treewise made these files itself, so they are removed, not
    /// trashed (ADR 0020).
    final class ArchiveCache: Sendable {
        private static let wholeArchiveKey = ""

        /// The copies of one archive, for as long as it has the same size and date.
        private struct Folder {
            var signature: ArchiveSignature
            var url: URL
            /// What is extracted or being extracted: the folder it lands in, per
            /// entry, or under `wholeArchiveKey` for all of the archive.
            var extractions: [String: Task<URL, any Error>] = [:]
        }

        private let root: URL
        private let folders = Mutex<[FileItem.ID: Folder]>([:])

        /// Creates a cache in a folder of its own below `parent`.
        init(in parent: URL) {
            root = parent.appendingPathComponent(UUID().uuidString)
        }

        /// A copy of a place; asking again gives the same copy.
        ///
        /// - Throws: `FileSystemError.notFound` when the archive is gone.
        func copy(of place: ArchivePath, in tree: ArchiveTree) async throws -> URL {
            guard let signature = ArchiveSignature(path: place.archive.rawValue) else {
                throw FileSystemError.notFound(place.id)
            }
            guard let selection = ArchiveSelection(place, in: tree) else {
                throw FileSystemError.notFound(place.id)
            }
            let whole = ArchiveCachePolicy.extractsWhole(
                archiveName: place.archive.rawValue, totalBytes: tree.byteCount(at: ""),
                freeBytes: freeBytes())
            let output = try await extraction(
                whole ? ArchiveSelection(wholeOf: place.archive) : selection,
                key: whole ? Self.wholeArchiveKey : place.entry, signature: signature
            ).value
            let copy = place.isTopLevel ? output : output.appendingPathComponent(place.entry)
            guard FileManager.default.fileExists(atPath: copy.path) else {
                throw FileSystemError.archiveDamaged(place.archive)
            }
            return copy
        }

        /// Removes the copies made from an archive.
        func release(_ archive: FileItem.ID) {
            guard let folder = folders.withLock({ $0.removeValue(forKey: archive) }) else { return }
            discard(folder)
        }

        /// Removes everything below `parent`.
        static func removeLeftovers(in parent: URL) {
            ArchiveWorkspace.remove(parent)
        }

        private func discard(_ folder: Folder) {
            for extraction in folder.extractions.values { extraction.cancel() }
            ArchiveWorkspace.remove(folder.url)
        }

        private func extraction(
            _ selection: ArchiveSelection, key: String, signature: ArchiveSignature
        ) -> Task<URL, any Error> {
            let (task, stale) = folders.withLock { folders -> (Task<URL, any Error>, Folder?) in
                var stale: Folder?
                var folder = folders[selection.archive]
                if let current = folder, current.signature != signature {
                    stale = current
                    folder = nil
                }
                var current =
                    folder
                    ?? Folder(
                        signature: signature,
                        url: root.appendingPathComponent(UUID().uuidString))
                let task =
                    current.extractions[key]
                    ?? start(selection, key: key, in: current.url)
                current.extractions[key] = task
                folders[selection.archive] = current
                return (task, stale)
            }
            if let stale { discard(stale) }
            return task
        }

        private func start(
            _ selection: ArchiveSelection, key: String, in folder: URL
        ) -> Task<URL, any Error> {
            let archive = selection.archive
            return Task.detached(priority: .userInitiated) { [self] in
                do {
                    return try await Self.extract(selection, in: folder)
                } catch {
                    forget(key, of: archive)
                    throw error
                }
            }
        }

        private func forget(_ key: String, of archive: FileItem.ID) {
            folders.withLock { $0[archive]?.extractions[key] = nil }
        }

        /// Runs `tar` off Swift's cooperative pool, as it blocks until it ends.
        private static func extract(_ selection: ArchiveSelection, in folder: URL) async throws
            -> URL
        {
            let control = TransferControl()
            let output = folder.appendingPathComponent(UUID().uuidString)
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(
                            with: Result {
                                try run(selection, into: output, in: folder, control: control)
                            })
                    }
                }
            } onCancel: {
                control.stop()
            }
        }

        private static func run(
            _ selection: ArchiveSelection, into output: URL, in folder: URL,
            control: TransferControl
        ) throws -> URL {
            do {
                try FileManager.default.createDirectory(
                    at: output, withIntermediateDirectories: true)
                try FileCoordination.read(selection.archiveURL) { _ in
                    try ArchiveEntryExtractor.extract(
                        selection, into: output, temporaryFolder: folder, control: control
                    ) { _ in }
                }
                return output
            } catch {
                ArchiveWorkspace.remove(output)
                throw error
            }
        }

        /// The free space where the copies go, or `nil` when it cannot be told.
        private func freeBytes() -> Int64? {
            var folder = root
            while !FileManager.default.fileExists(atPath: folder.path), folder.path != "/" {
                folder.deleteLastPathComponent()
            }
            return
                (try? folder.resourceValues(forKeys: [
                    .volumeAvailableCapacityForImportantUsageKey
                ]))?
                .volumeAvailableCapacityForImportantUsage
        }
    }
#endif
