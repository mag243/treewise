import Foundation
import TreewiseCore

/// The inside of an archive as folders and files (ADR 0076).
extension LocalFileSystem {
    #if os(macOS)
        func archiveContents(of place: ArchivePath) async throws -> [FileItem] {
            guard let items = try await archiveTree(for: place).items(in: place) else {
                throw FileSystemError.notFound(place.id)
            }
            return items
        }

        func archiveItem(at place: ArchivePath) async throws -> FileItem {
            guard !place.isTopLevel else { return try currentArchiveItem(at: place) }
            guard let item = try await archiveTree(for: place).item(at: place) else {
                throw FileSystemError.notFound(place.id)
            }
            return item
        }

        /// The item of a place without waiting for a listing. Before its listing
        /// was read, a place counts as a folder: only restoring a window asks
        /// then, and a tab that shows a place that is gone recovers from it.
        func currentArchiveItem(at place: ArchivePath) throws -> FileItem {
            guard ArchiveSignature(path: place.archive.rawValue) != nil else {
                throw FileSystemError.notFound(place.id)
            }
            guard !place.isTopLevel else { return ArchiveTree.topLevelItem(of: place) }
            let tree =
                archiveCatalog.currentTree(of: place.archive)
                ?? ArchiveTree(entries: [
                    ArchiveEntry(storedName: place.entry, isFolder: true, size: 0, modified: nil)
                ])
            guard let item = tree.item(at: place) else {
                throw FileSystemError.notFound(place.id)
            }
            return item
        }

        /// The listing of the archive a place is in.
        ///
        /// - Throws: `FileSystemError.notFound` for the place when the archive is gone.
        func archiveTree(for place: ArchivePath) async throws -> ArchiveTree {
            do {
                return try await archiveCatalog.tree(of: place.archive)
            } catch FileSystemError.notFound {
                throw FileSystemError.notFound(place.id)
            }
        }
    #else
        func archiveContents(of place: ArchivePath) async throws -> [FileItem] {
            throw FileSystemError.notFound(place.id)
        }

        func archiveItem(at place: ArchivePath) async throws -> FileItem {
            throw FileSystemError.notFound(place.id)
        }

        func currentArchiveItem(at place: ArchivePath) throws -> FileItem {
            throw FileSystemError.notFound(place.id)
        }
    #endif
}
