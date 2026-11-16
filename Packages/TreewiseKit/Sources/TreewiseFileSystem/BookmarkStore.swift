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
    /// The folder's name when it was added, to name it while it cannot be reached; `nil`
    /// for a bookmark saved before names were kept.
    public var name: String?
}

/// A bookmark resolved to its folder.
public struct ResolvedBookmark: Sendable {
    /// The folder it points to.
    public let url: URL
    /// Whether the system asks for its data to be made again, inside the folder's scope.
    public let isStale: Bool
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
/// on every launch, renewed when the system reports them stale. iOS makes bookmark data
/// only inside a folder's security scope, so renewing is a step of its own, after the
/// scope has started (audit 2026-11, A18).
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
        let bookmark = try newBookmark(for: url)
        saved.append(bookmark)
        storage.save(saved)
        return bookmark
    }

    /// Returns the folder a bookmark points to, and whether its data should be renewed;
    /// the data itself is left alone.
    ///
    /// - Throws: when the bookmark cannot be resolved, for example because its folder was deleted.
    public func resolve(_ bookmark: Bookmark) throws -> ResolvedBookmark {
        let (url, isStale) = try resolver.resolve(bookmark.data)
        return ResolvedBookmark(url: url, isStale: isStale)
    }

    /// Makes a stale bookmark's data again for its folder, which must be in scope.
    ///
    /// - Throws: when the system cannot make bookmark data for `url`.
    public func renew(_ bookmark: Bookmark, for url: URL) throws {
        guard let index = saved.firstIndex(where: { $0.id == bookmark.id }) else { return }
        saved[index].data = try resolver.bookmarkData(for: url)
        saved[index].refreshCount += 1
        storage.save(saved)
    }

    /// Puts a bookmark for `url` in the place of `old`, as when a folder that could not
    /// be reached is picked again.
    ///
    /// - Throws: when the system cannot make bookmark data for `url`.
    public func replace(_ old: Bookmark, with url: URL) throws -> Bookmark {
        let bookmark = try newBookmark(for: url)
        if let index = saved.firstIndex(where: { $0.id == old.id }) {
            saved[index] = bookmark
        } else {
            saved.append(bookmark)
        }
        storage.save(saved)
        return bookmark
    }

    private func newBookmark(for url: URL) throws -> Bookmark {
        Bookmark(
            id: UUID(), data: try resolver.bookmarkData(for: url), refreshCount: 0,
            name: url.lastPathComponent)
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
