import Foundation
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
