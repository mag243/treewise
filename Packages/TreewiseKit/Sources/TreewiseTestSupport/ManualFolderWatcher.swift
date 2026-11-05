import Synchronization
import TreewiseCore

/// A folder watcher whose changes a test sends by hand.
public final class ManualFolderWatcher: FolderWatching {
    private let continuations = Mutex<[FileItem.ID: [AsyncStream<Void>.Continuation]]>([:])

    /// Creates a watcher without watched folders.
    public init() {}

    /// The folders someone is watching right now.
    public var watchedFolders: Set<FileItem.ID> {
        continuations.withLock { Set($0.filter { !$0.value.isEmpty }.keys) }
    }

    public func changes(of folder: FileItem.ID) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations.withLock { $0[folder, default: []].append(continuation) }
        return stream
    }

    /// Reports a change in `folder` to everyone watching it.
    public func change(_ folder: FileItem.ID) {
        let watching = continuations.withLock { $0[folder] ?? [] }
        for continuation in watching { continuation.yield() }
    }
}
