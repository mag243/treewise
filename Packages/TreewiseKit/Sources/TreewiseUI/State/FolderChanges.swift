import Foundation
import TreewiseCore

/// The folders whose entries Treewise changed, one set for each operation, undo and redo,
/// heard by every window that shares it, so each sidebar reads those rows again, also of a
/// folder no pane shows and no watcher follows (ADR 0112).
@MainActor
public final class FolderChanges {
    private var listeners: [UUID: AsyncStream<Set<FileItem.ID>>.Continuation] = [:]

    public init() {}

    /// The sets of folders changed after the call, each kept until it is read, so none is
    /// lost while the listener is busy. Ending the iteration stops the listening.
    public func changes() -> AsyncStream<Set<FileItem.ID>> {
        let (stream, continuation) = AsyncStream<Set<FileItem.ID>>.makeStream()
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        return stream
    }

    /// Tells every listener that the entries of `folders` changed.
    func note(_ folders: Set<FileItem.ID>) {
        guard !folders.isEmpty else { return }
        for listener in listeners.values { listener.yield(folders) }
    }
}
