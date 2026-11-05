import Foundation
import Synchronization

/// A saved reference to a folder the user gave access to, which survives the
/// folder being renamed or moved (ADR 0006).
public struct Bookmark: Identifiable, Hashable, Sendable, Codable {
    /// The bookmark's identity, stable across refreshes.
    public let id: UUID
    /// The system's bookmark data.
    public var data: Data
    /// How often the data was renewed because the system reported it stale.
    public var refreshCount: Int
}

/// Makes and resolves bookmark data; the system's implementation or a fake.
public protocol BookmarkResolving: Sendable {
    /// Returns bookmark data for a URL.
    func bookmarkData(for url: URL) throws -> Data
    /// Returns the URL bookmark data points to, and whether the data should be renewed.
    func resolve(_ data: Data) throws -> (url: URL, isStale: Bool)
}

/// Keeps bookmarks between launches.
public protocol BookmarkStorage: Sendable {
    /// Returns the saved bookmarks.
    func load() -> [Bookmark]
    /// Saves the bookmarks, replacing the previous ones.
    func save(_ bookmarks: [Bookmark])
}

/// The bookmarks of the folders the user gave access to: added once, resolved
/// on every launch, renewed when the system reports them stale.
public actor BookmarkStore {
    private let storage: any BookmarkStorage
    private let resolver: any BookmarkResolving
    private var saved: [Bookmark]

    /// Creates a store that keeps its bookmarks in `storage`.
    public init(
        storage: any BookmarkStorage, resolver: any BookmarkResolving = SystemBookmarkResolver()
    ) {
        self.storage = storage
        self.resolver = resolver
        saved = storage.load()
    }

    /// The saved bookmarks, oldest first.
    public func bookmarks() -> [Bookmark] {
        saved
    }

    /// Saves a bookmark for a folder.
    ///
    /// - Throws: when the system cannot make bookmark data for `url`.
    public func add(_ url: URL) throws -> Bookmark {
        let bookmark = Bookmark(
            id: UUID(), data: try resolver.bookmarkData(for: url), refreshCount: 0)
        saved.append(bookmark)
        storage.save(saved)
        return bookmark
    }

    /// Returns the folder a bookmark points to, renewing its data when stale.
    ///
    /// - Throws: when the bookmark cannot be resolved, for example because its folder was deleted.
    public func resolve(_ bookmark: Bookmark) throws -> URL {
        let (url, isStale) = try resolver.resolve(bookmark.data)
        if isStale, let index = saved.firstIndex(where: { $0.id == bookmark.id }) {
            saved[index].data = try resolver.bookmarkData(for: url)
            saved[index].refreshCount += 1
            storage.save(saved)
        }
        return url
    }

    /// Forgets a bookmark.
    public func remove(_ bookmark: Bookmark) {
        saved.removeAll { $0.id == bookmark.id }
        storage.save(saved)
    }
}

/// Plain bookmarks from Foundation. A sandboxed build will add security scope.
public struct SystemBookmarkResolver: BookmarkResolving {
    /// Creates the system resolver.
    public init() {}

    public func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData()
    }

    public func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        return (url, isStale)
    }
}

/// Keeps bookmarks only in memory, so nothing is written to disk (M2).
public final class InMemoryBookmarkStorage: BookmarkStorage {
    private let bookmarks = Mutex<[Bookmark]>([])

    /// Creates empty storage.
    public init() {}

    public func load() -> [Bookmark] {
        bookmarks.withLock { $0 }
    }

    public func save(_ bookmarks: [Bookmark]) {
        self.bookmarks.withLock { $0 = bookmarks }
    }
}
