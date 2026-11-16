import Foundation
import TreewiseCore
import os

/// The folders the user added through the document picker on iOS (ADR 0045):
/// kept as bookmarks, resolved on every launch, and accessed for as long as
/// they are added.
///
/// iOS lets an app into a picked folder only while it holds the folder's
/// security scope. The scope covers the folder's whole tree for the process,
/// so items under it can be read through fresh URLs of their paths.
///
/// A folder that cannot be reached at launch, such as one on a drive that is not
/// attached, is kept and listed as unavailable, to be picked again (ADR 0111).
///
/// Invariant: every listed folder's scope was started once and is stopped when
/// the folder is removed.
public actor AddedFolders {
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "locations")

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
    private var missing: [Bookmark] = []

    /// Creates the list over `store`; `load()` resolves its bookmarks.
    public init(store: BookmarkStore) {
        self.store = store
    }

    /// The added folders that resolved, in the order they were added.
    public func folders() -> [URL] {
        added.map(\.url)
    }

    /// The saved folders that could not be reached at the last `load()`, oldest first.
    public func unavailable() -> [Bookmark] {
        missing
    }

    /// Resolves the saved bookmarks and starts their scopes. A bookmark whose
    /// folder cannot be resolved or reached, such as one on a drive that is not
    /// connected, is listed as unavailable and kept for a later launch. A stale
    /// bookmark is renewed inside its folder's scope; when that fails, its folder
    /// stays added with the old data.
    public func load() async {
        stopAll()
        missing = []
        for bookmark in await store.bookmarks() {
            guard let resolved = try? await store.resolve(bookmark) else {
                missing.append(bookmark)
                continue
            }
            let url = resolved.url
            let isScoped = url.startAccessingSecurityScopedResource()
            guard (try? url.checkResourceIsReachable()) == true else {
                if isScoped { url.stopAccessingSecurityScopedResource() }
                missing.append(bookmark)
                continue
            }
            if resolved.isStale { await renew(bookmark, for: url) }
            added.append(Added(bookmark: bookmark, url: url, isScoped: isScoped))
        }
    }

    /// Puts a folder the user picked in the place of one that could not be reached.
    ///
    /// - Throws: when the system cannot make a bookmark for the folder.
    public func reconnect(_ bookmark: Bookmark, to url: URL) async throws {
        guard index(of: url) == nil else {
            await store.remove(bookmark)
            missing.removeAll { $0.id == bookmark.id }
            return
        }
        let isScoped = url.startAccessingSecurityScopedResource()
        do {
            let renewed = try await store.replace(bookmark, with: url)
            added.append(Added(bookmark: renewed, url: url, isScoped: isScoped))
            missing.removeAll { $0.id == bookmark.id }
        } catch {
            if isScoped { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    /// Forgets a folder that could not be reached.
    public func forget(_ bookmark: Bookmark) async {
        missing.removeAll { $0.id == bookmark.id }
        await store.remove(bookmark)
    }

    private func renew(_ bookmark: Bookmark, for url: URL) async {
        do {
            try await store.renew(bookmark, for: url)
        } catch {
            Self.logger.error("A stale bookmark was not renewed: \(error.localizedDescription)")
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
