/// Reports changes to the entries of a folder, so a tab can reload it.
public protocol FolderWatching: Sendable {
    /// Returns a stream that yields whenever an entry is created, deleted or
    /// renamed in `folder`, and finishes when the folder itself goes away or
    /// cannot be watched. Ending the iteration stops the watching.
    func changes(of folder: FileItem.ID) -> AsyncStream<Void>
}
