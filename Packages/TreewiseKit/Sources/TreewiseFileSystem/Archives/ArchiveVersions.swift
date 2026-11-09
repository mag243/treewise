#if os(macOS)
    import Foundation
    import Synchronization
    import TreewiseCore

    /// The versions of changed archives that undo may need (ADR 0078), in a
    /// hidden folder next to each archive. The first time an archive changes, a
    /// copy of the original also goes to the Trash. Versions are Treewise's own,
    /// so they are removed, not trashed (ADR 0020).
    final class ArchiveVersions: Sendable {
        private static let registryName = "versions"

        private let folders = Mutex<[FileItem.ID: URL]>([:])
        private let moveToTrash: @Sendable (URL) throws -> Void
        private let registry: URL

        /// Creates the keeper of versions for these locations.
        init(locations: LocalFileSystem.Locations) {
            moveToTrash = locations.moveToTrash
            registry = locations.archiveCacheFolder.appendingPathComponent(Self.registryName)
        }

        /// Keeps a version of the archive as it is now; the first time, its
        /// original also goes to the Trash, on a volume that has one.
        ///
        /// - Returns: the kept file.
        func keepCurrent(of archive: FileItem.ID, in workspace: ArchiveWorkspace) throws -> URL {
            let file = URL(fileURLWithPath: archive.rawValue)
            let isFirst = folders.withLock { $0[archive] == nil }
            let kept = try keep(file, of: archive)
            if isFirst {
                let copy = workspace.url.appendingPathComponent(file.lastPathComponent)
                try FileManager.default.copyItem(at: file, to: copy)
                do {
                    try moveToTrash(copy)
                } catch FileSystemError.trashUnavailable {
                    // The hidden version still serves undo on such a volume.
                }
            }
            return kept
        }

        /// Keeps a version, for redo, without touching the Trash.
        func keep(_ file: URL, of archive: FileItem.ID) throws -> URL {
            let folder = try folder(for: file, of: archive)
            let kept = folder.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: file, to: kept)
            return kept
        }

        /// Removes every folder of versions a registry names, also those an
        /// earlier run left. Only hidden folders of Treewise's own are touched.
        static func removeAll(in locations: LocalFileSystem.Locations) {
            let registry = locations.archiveCacheFolder.appendingPathComponent(registryName)
            guard let text = try? String(contentsOf: registry, encoding: .utf8) else { return }
            for path in text.split(separator: "\n").map(String.init) {
                let folder = URL(fileURLWithPath: path)
                guard folder.lastPathComponent.hasPrefix(FileCopier.partialPrefix) else { continue }
                ArchiveWorkspace.remove(folder)
            }
        }

        private func folder(for file: URL, of archive: FileItem.ID) throws -> URL {
            if let known = folders.withLock({ $0[archive] }) { return known }
            let workspace = try ArchiveWorkspace(in: file.deletingLastPathComponent())
            try remember(workspace.url)
            folders.withLock { $0[archive] = workspace.url }
            return workspace.url
        }

        private func remember(_ folder: URL) throws {
            try FileManager.default.createDirectory(
                at: registry.deletingLastPathComponent(), withIntermediateDirectories: true)
            let line = Data((folder.path + "\n").utf8)
            if let handle = FileHandle(forWritingAtPath: registry.path) {
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                try handle.close()
            } else {
                try line.write(to: registry)
            }
        }
    }
#endif
