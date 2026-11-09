import Foundation
import Synchronization
import TreewiseCore

/// Watches a folder's entries with a `DispatchSource` on its file descriptor
/// (ADR 0016): created, deleted and renamed entries arrive within
/// milliseconds; content changes and subfolders do not. This Mac follows the
/// kernel's mount table instead (ADR 0046). `O_EVTONLY` keeps a watched
/// volume free to eject. A folder `watchesFileChanges` names also reports its
/// files changing, such as a download that ends (ADR 0051).
public struct DirectoryWatcher: FolderWatching {
    private let mountTableChanges: @Sendable () -> AsyncStream<Void>
    private let watchesFileChanges: @Sendable (FileItem.ID) -> Bool

    /// Creates a watcher; `mountTableChanges` reports the changes of This Mac,
    /// `watchesFileChanges` names the folders whose files are followed too.
    public init(
        mountTableChanges: @escaping @Sendable () -> AsyncStream<Void> = MountTable.changes,
        watchesFileChanges: @escaping @Sendable (FileItem.ID) -> Bool = { _ in false }
    ) {
        self.mountTableChanges = mountTableChanges
        self.watchesFileChanges = watchesFileChanges
    }

    public func changes(of folder: FileItem.ID) -> AsyncStream<Void> {
        if folder == .computer { return mountTableChanges() }
        #if os(macOS)
            if let place = ArchivePath(folder) { return changes(ofArchive: place.archive) }
        #endif
        let path = folder.rawValue
        return AsyncStream { continuation in
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else {
                continuation.finish()
                return
            }
            // .write: an entry was created, deleted or renamed; .delete and .rename:
            // the folder itself went away; .revoke: its volume was ejected.
            let gone: DispatchSource.FileSystemEvent = [.delete, .rename, .revoke]
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: gone.union(.write),
                queue: DispatchQueue(label: "Treewise.DirectoryWatcher"))
            source.setEventHandler {
                continuation.yield()
                // The folder itself went away: nothing left to watch.
                if !source.data.isDisjoint(with: gone) { continuation.finish() }
            }
            source.setCancelHandler { close(descriptor) }
            let stopFileEvents = fileEvents(of: folder) { continuation.yield() }
            continuation.onTermination = { _ in
                source.cancel()
                stopFileEvents?()
            }
            source.resume()
        }
    }

    #if os(macOS)
        /// Reports an archive changing or going away, heard through the folder
        /// that holds it: something else in that folder changing is no change
        /// to the archive, so its size and date decide (ADR 0076).
        private func changes(ofArchive archive: FileItem.ID) -> AsyncStream<Void> {
            let path = archive.rawValue
            let folder = (path as NSString).deletingLastPathComponent
            return AsyncStream { continuation in
                let last = Mutex(ArchiveSignature(path: path))
                let stop = FileEvents.watch(folder: folder) {
                    let current = ArchiveSignature(path: path)
                    let changed = last.withLock { signature -> Bool in
                        defer { signature = current }
                        return signature != current
                    }
                    guard changed else { return }
                    continuation.yield()
                    if current == nil { continuation.finish() }
                }
                guard let stop else {
                    continuation.finish()
                    return
                }
                continuation.onTermination = { _ in stop() }
            }
        }
    #endif

    private func fileEvents(
        of folder: FileItem.ID, onChange: @escaping @Sendable () -> Void
    ) -> (@Sendable () -> Void)? {
        #if os(macOS)
            guard watchesFileChanges(folder) else { return nil }
            return FileEvents.watch(folder: folder.rawValue, onChange: onChange)
        #else
            return nil
        #endif
    }
}
