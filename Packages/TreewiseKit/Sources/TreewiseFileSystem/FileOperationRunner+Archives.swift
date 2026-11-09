#if os(macOS)
    import Foundation
    import TreewiseCore

    extension FileOperationRunner: ArchiveOperating {
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
