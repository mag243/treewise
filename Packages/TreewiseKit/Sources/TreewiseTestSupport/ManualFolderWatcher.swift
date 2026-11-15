import Foundation
import Synchronization
import TreewiseCore

/// A folder watcher whose changes a test sends by hand.
public final class ManualFolderWatcher: FolderWatching {
    private let continuations = Mutex<[FileItem.ID: [UUID: AsyncStream<Void>.Continuation]]>([:])

    /// Creates a watcher without watched folders.
    public init() {}

    /// The folders someone is watching right now.
    public var watchedFolders: Set<FileItem.ID> {
        continuations.withLock { Set($0.filter { !$0.value.isEmpty }.keys) }
    }

    /// A stream of `folder`'s changes, which stops counting as watched once whoever
    /// reads it stops, as the disk's watcher stops its events then.
    public func changes(of folder: FileItem.ID) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { $0[folder]?[id] = nil }
        }
        continuations.withLock { $0[folder, default: [:]][id] = continuation }
        return stream
    }

    /// Reports a change in `folder` to everyone watching it.
    public func change(_ folder: FileItem.ID) {
        let watching = continuations.withLock { Array(($0[folder] ?? [:]).values) }
        for continuation in watching { continuation.yield() }
    }
}
