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
    }
#endif
