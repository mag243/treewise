#if os(macOS)
    import Foundation
    import TreewiseCore

    extension FileOperationRunner: ArchiveOperating {
        /// Copies an entry out of an archive, through a hidden folder next to
        /// `target`. A file promised to another app does not coordinate
        /// `target`: that app holds it until the file is written.
        func copyOut(
            _ place: ArchivePath, to target: URL, onFile: @escaping FileCopyProgress,
            control: TransferControl, coordinatesTarget: Bool = true
        ) async throws -> FileItem {
            let tree = try await reader.archiveTree(for: place)
            guard let selection = ArchiveSelection(place, in: tree) else {
                throw FileSystemError.notFound(place.id)
            }
            try await FileCopier.run(control: control) {
                var copied: Int64 = 0
                let onEntry: (String) -> Void = { name in
                    copied += tree.node(forStoredName: name)?.entry?.size ?? 0
                    onFile((name as NSString).lastPathComponent, copied)
                }
                let copy: (URL) throws -> Void = { target in
                    try ArchiveEntryExtractor.copy(
                        selection, to: target, control: control, onEntry: onEntry)
                }
                if coordinatesTarget {
                    try FileCoordination.read(selection.archiveURL, andWrite: target) { _, target in
                        try copy(target)
                    }
                } else {
                    try FileCoordination.read(selection.archiveURL) { _ in try copy(target) }
                }
            }
            return try await reader.item(at: FileItem.ID(target.path))
        }

        public func writeEntry(_ entry: FileItem, toPromisedFile file: URL) async throws {
            guard let place = ArchivePath(entry.id) else {
                throw FileSystemError.notFound(entry.id)
            }
            try reader.checkBoundary(entry.id)
            try reader.checkBoundary(
                FileItem.ID(file.deletingLastPathComponent().standardizedFileURL.path))
            _ = try await copyOut(
                place, to: file, onFile: { _, _ in }, control: TransferControl(),
                coordinatesTarget: false)
        }

        public func cachedCopy(of item: FileItem) async throws -> URL {
            guard let place = ArchivePath(item.id) else { return url(item.id) }
            try reader.checkBoundary(item.id)
            let tree = try await reader.archiveTree(for: place)
            return try await archiveCache.copy(of: place, in: tree)
        }

        public func apply(
            _ edit: ArchiveEdit, to archive: FileItem.ID,
            onProgress: @escaping ArchiveProgressHandler, control: TransferControl
        ) async throws {
            try reader.checkBoundary(archive)
            let place = ArchivePath(archive: archive)
            guard place.isChangeable else { throw FileSystemError.archiveReadOnly }
            let job = ArchiveUpdater.Job(
                archive: archive, edit: edit, tree: try await reader.archiveTree(for: place))
            try await FileCopier.run(control: control) {
                try ArchiveUpdater.apply(job, onProgress: onProgress, control: control)
            }
        }

        public func releaseCache(of archive: FileItem.ID) async {
            reader.archiveCatalog.stopReading(of: archive)
            archiveCache.release(archive)
        }

        /// Removes the copies an earlier run left behind. Call once, at launch,
        /// before any window has made copies.
        public static func removeLeftoverArchiveCopies(in locations: LocalFileSystem.Locations) {
            ArchiveCache.removeLeftovers(in: locations.archiveCacheFolder)
        }

        public func extract(
            _ archive: FileItem, into folder: FileItem.ID, as name: String,
            onProgress: @escaping ArchiveProgressHandler, control: TransferControl
        ) async throws -> FileItem {
            try reader.checkBoundary(archive.id)
            try reader.checkBoundary(folder)
            let (source, target) = (url(archive.id), url(folder).appendingPathComponent(name))
            try await FileCopier.run(control: control) {
                try FileCoordination.read(source, andWrite: target) { source, target in
                    try ArchiveExtractor.extract(
                        source, to: target, onProgress: onProgress, control: control)
                }
            }
            return try await reader.item(at: FileItem.ID(target.path))
        }

        public func compress(
            _ items: [FileItem], to archive: NewArchive,
            onProgress: @escaping ArchiveProgressHandler, control: TransferControl
        ) async throws -> FileItem {
            precondition(!items.isEmpty, "items is not empty")
            precondition(Set(items.map(\.parentID)).count == 1, "items share a parent folder")
            for item in items { try reader.checkBoundary(item.id) }
            try reader.checkBoundary(archive.folder)
            let sources = items.map { url($0.id) }
            let target = url(archive.folder).appendingPathComponent(archive.name)
            let format = archive.format
            try await FileCopier.run(control: control) {
                try FileCoordination.read(sources, andWrite: target) {
                    try ArchiveCompressor.compress(
                        sources, to: target, format: format, onProgress: onProgress,
                        control: control)
                }
            }
            return try await reader.item(at: FileItem.ID(target.path))
        }
    }
#endif
