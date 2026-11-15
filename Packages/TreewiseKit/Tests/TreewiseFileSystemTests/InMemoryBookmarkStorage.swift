import Foundation
import Synchronization
import TreewiseFileSystem

/// Keeps bookmarks only in memory, so the tests write nothing to disk.
final class InMemoryBookmarkStorage: BookmarkStorage {
    private let bookmarks = Mutex<[Bookmark]>([])

    /// Creates empty storage.
    init() {}

    func load() -> [Bookmark] {
        bookmarks.withLock { $0 }
    }

    func save(_ bookmarks: [Bookmark]) {
        self.bookmarks.withLock { $0 = bookmarks }
    }
}
