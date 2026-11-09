import Foundation
import TreewiseCore

/// Changes files on the local disk (ADR 0018), one operation at a time.
///
/// Every copy is made under a hidden partial name in the target and gets its
/// real name only when complete, so a failed or cancelled copy leaves nothing
/// behind. A move across volumes is a copy, a check that the copy has the same
/// size and number of items, and only then the removal of the source: the one
/// place where Treewise removes a user's file without the Trash (ADR 0004).
public actor FileOperationRunner: FileOperating {
    let reader: LocalFileSystem
    private let trashService = TrashService()
    #if os(macOS)
        /// The copies of entries of archives this window shows (ADR 0076).
        let archiveCache: ArchiveCache
        /// The kept versions of the archives this window changed (ADR 0078).
        let archiveVersions: ArchiveVersions
    #endif

    /// Creates a runner that reads and writes the local disk.
    public init(locations: LocalFileSystem.Locations = .system) {
        reader = LocalFileSystem(locations: locations)
        #if os(macOS)
            archiveCache = ArchiveCache(in: locations.archiveCacheFolder)
            archiveVersions = ArchiveVersions(locations: locations)
        #endif
    }

    public func contents(of folder: FileItem.ID) async throws -> [FileItem] {
        try await reader.contents(of: folder)
    }

    public func item(at id: FileItem.ID) async throws -> FileItem {
        try await reader.item(at: id)
    }

    public func locations() async throws -> [FileItem] {
        try await reader.locations()
    }

    public func favorites() async throws -> [FileItem] {
        try await reader.favorites()
    }

    public func availableCapacity(of folder: FileItem.ID) async throws -> Int64? {
        try await reader.availableCapacity(of: folder)
    }

    #if os(macOS)
        /// Ejects a volume (ADR 0044).
        public func eject(_ volume: FileItem.ID) async throws {
            try await reader.eject(volume)
        }
    #endif

    /// Hidden items count: a hidden file with the same name still blocks it.
    public func itemsByName(in folder: FileItem.ID) async throws -> [String: FileItem] {
        Dictionary(try await reader.contents(of: folder).map { ($0.name, $0) }) { first, _ in
            first
        }
    }

    public func byteCount(of item: FileItem) async throws -> Int64 {
        try reader.checkBoundary(item.id)
        #if os(macOS)
            if let place = ArchivePath(item.id) {
                return try await reader.archiveTree(for: place).byteCount(at: place.entry)
            }
        #endif
        return Int64(FileCopier.footprint(of: url(item.id)).size)
    }

    public func copy(
        _ item: FileItem, into folder: FileItem.ID, as name: String,
        onFile: @escaping FileCopyProgress, control: TransferControl
    ) async throws -> FileItem {
        try reader.checkBoundary(item.id)
        try reader.checkBoundary(folder)
        try refuseInsideArchive(folder)
        #if os(macOS)
            if let place = ArchivePath(item.id) {
                return try await copyOut(
                    place, to: url(folder).appendingPathComponent(name), onFile: onFile,
                    control: control)
            }
        #endif
        let (source, target) = (url(item.id), url(folder).appendingPathComponent(name))
        let copy = try await FileCopier.run(control: control) {
            try FileCoordination.read(source, andWrite: target) { source, target in
                try FileCopier.copyCompletely(
                    source, into: target.deletingLastPathComponent(), as: name, onFile: onFile,
                    control: control)
            }
        }
        return try await reader.item(at: FileItem.ID(copy.path))
    }

    public func move(
        _ item: FileItem, into folder: FileItem.ID, as name: String,
        onFile: @escaping FileCopyProgress, control: TransferControl
    ) async throws -> FileItem {
        try reader.checkBoundary(item.id)
        try refuseInsideArchive(item.id)
        try refuseInsideArchive(folder)
        let target = try await reader.item(at: folder)
        let destination = url(folder).appendingPathComponent(name)
        if target.volume == item.volume {
            let source = url(item.id)
            try await FileCopier.run(control: control) {
                try Self.mapping(item.id) {
                    try FileCoordination.move(source, to: destination) {
                        try FileManager.default.moveItem(at: $0, to: $1)
                    }
                }
            }
        } else {
            try await moveAcrossVolumes(
                item, into: url(folder), as: name, onFile: onFile, control: control)
        }
        return try await reader.item(at: FileItem.ID(destination.path))
    }

    public func trash(_ id: FileItem.ID) async throws -> TrashedItem {
        try reader.checkBoundary(id)
        try refuseInsideArchive(id)
        let trashService = trashService
        return try await FileCopier.run {
            try Self.mapping(id) {
                try FileCoordination.delete(URL(fileURLWithPath: id.rawValue)) { _ in
                    try trashService.trash(id)
                }
            }
        }
    }

    /// The Trash may be outside the boundary, wherever `trashItem` put the
    /// item; the place it goes back to may not.
    public func restore(_ trashed: TrashedItem) async throws -> FileItem {
        try reader.checkBoundary(trashed.originalID)
        let trashService = trashService
        try await FileCopier.run {
            try Self.mapping(trashed.originalID) {
                try FileCoordination.move(
                    URL(fileURLWithPath: trashed.trashID.rawValue),
                    to: URL(fileURLWithPath: trashed.originalID.rawValue)
                ) { _, _ in try trashService.restore(trashed) }
            }
        }
        return try await reader.item(at: trashed.originalID)
    }

    public func createFolder(in folder: FileItem.ID, named name: String) async throws -> FileItem {
        try reader.checkBoundary(folder)
        try refuseInsideArchive(folder)
        let created = url(folder).appendingPathComponent(name)
        try await FileCopier.run {
            try Self.mapping(folder) {
                try FileCoordination.write(created) {
                    try FileManager.default.createDirectory(
                        at: $0, withIntermediateDirectories: false)
                }
            }
        }
        return try await reader.item(at: FileItem.ID(created.path))
    }

    func url(_ id: FileItem.ID) -> URL {
        URL(fileURLWithPath: id.rawValue)
    }

    /// A second lock behind the rules: an archive cannot be changed (ADR 0076).
    private func refuseInsideArchive(_ id: FileItem.ID) throws {
        if id.isInsideArchive { throw FileSystemError.notWritable(id) }
    }

    /// Copy, verify, then remove the source, on the copy queue (ADR 0026). On
    /// a mismatch the copy goes and the source stays.
    private func moveAcrossVolumes(
        _ item: FileItem, into folder: URL, as name: String, onFile: @escaping FileCopyProgress,
        control: TransferControl
    ) async throws {
        let source = url(item.id)
        try await FileCopier.run(control: control) {
            let target = folder.appendingPathComponent(name)
            try FileCoordination.read(source, andWrite: target) { source, target in
                let copy = try FileCopier.copyCompletely(
                    source, into: target.deletingLastPathComponent(), as: name, onFile: onFile,
                    control: control)
                guard FileCopier.footprint(of: copy) == FileCopier.footprint(of: source) else {
                    try? FileManager.default.removeItem(at: copy)
                    throw FileSystemError.verificationFailed(item.id)
                }
            }
            try Self.mapping(item.id) {
                try FileCoordination.delete(source) { try FileManager.default.removeItem(at: $0) }
            }
        }
    }

    private nonisolated static func mapping<Value>(
        _ id: FileItem.ID, _ body: () throws -> Value
    ) throws -> Value {
        do {
            return try body()
        } catch {
            throw TrashService.error(error, for: id)
        }
    }
}

#if os(macOS)
    extension FileOperationRunner: VolumeEjecting {}
#endif
