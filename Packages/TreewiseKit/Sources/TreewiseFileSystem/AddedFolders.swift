import Foundation

/// The folders the user added through the document picker on iOS (ADR 0045):
/// kept as bookmarks, resolved on every launch, and accessed for as long as
/// they are added.
///
/// iOS lets an app into a picked folder only while it holds the folder's
/// security scope. The scope covers the folder's whole tree for the process,
/// so items under it can be read through fresh URLs of their paths.
///
/// Invariant: every listed folder's scope was started once and is stopped when
/// the folder is removed.
public actor AddedFolders {
    private struct Added {
        let bookmark: Bookmark
        let url: URL
        /// Whether `startAccessingSecurityScopedResource()` returned true,
        /// so the scope must be stopped again; a folder that needs no scope,
        /// as on the Mac, returns false.
        let isScoped: Bool
    }

    private let store: BookmarkStore
    private var added: [Added] = []

    /// Creates the list over `store`; `load()` resolves its bookmarks.
    public init(store: BookmarkStore) {
        self.store = store
    }

    /// The added folders that resolved, in the order they were added.
    public func folders() -> [URL] {
        added.map(\.url)
    }

    /// Resolves the saved bookmarks and starts their scopes. A bookmark whose
    /// folder cannot be resolved, such as one on a drive that is not
    /// connected, is left out and kept for a later launch.
    public func load() async {
        stopAll()
        for bookmark in await store.bookmarks() {
            guard let url = try? await store.resolve(bookmark) else { continue }
            let isScoped = url.startAccessingSecurityScopedResource()
            guard (try? url.checkResourceIsReachable()) == true else {
                if isScoped { url.stopAccessingSecurityScopedResource() }
                continue
            }
            added.append(Added(bookmark: bookmark, url: url, isScoped: isScoped))
        }
    }

    /// Adds a folder the user picked; a folder already added stays once.
    ///
    /// - Throws: when the system cannot make a bookmark for the folder.
    public func add(_ url: URL) async throws {
        guard index(of: url) == nil else { return }
        // A picked folder's bookmark can only be made inside its scope.
        let isScoped = url.startAccessingSecurityScopedResource()
        do {
            let bookmark = try await store.add(url)
            added.append(Added(bookmark: bookmark, url: url, isScoped: isScoped))
        } catch {
            if isScoped { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    /// Forgets a folder and stops its scope.
    public func remove(_ url: URL) async {
        guard let index = index(of: url) else { return }
        let folder = added.remove(at: index)
        if folder.isScoped { folder.url.stopAccessingSecurityScopedResource() }
        await store.remove(folder.bookmark)
    }

    private func stopAll() {
        for folder in added where folder.isScoped {
            folder.url.stopAccessingSecurityScopedResource()
        }
        added = []
    }

    private func index(of url: URL) -> Int? {
        let path = url.resolvingSymlinksInPath().path
        return added.firstIndex { $0.url.resolvingSymlinksInPath().path == path }
    }
}
