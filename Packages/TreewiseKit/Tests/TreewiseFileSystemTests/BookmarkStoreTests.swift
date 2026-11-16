import Foundation
import Testing
import TreewiseFileSystem
import TreewiseTestSupport

/// Saving and restoring folder access (PLAN.md §9.3, ADR 0006).
@Suite struct BookmarkStoreTests {
    /// Resolves bookmark data that is just the path, reports it stale when asked, and fails
    /// to make new data when asked, as iOS does outside a folder's security scope.
    struct FakeResolver: BookmarkResolving {
        struct CannotMakeData: Error {}

        var stale = false
        var cannotRenew = false

        func bookmarkData(for url: URL) throws -> Data {
            if cannotRenew { throw CannotMakeData() }
            return Data(url.path.utf8)
        }

        func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
            (URL(fileURLWithPath: String(bytes: data, encoding: .utf8) ?? "/"), stale)
        }
    }

    @Test func restoresAFolderItSaved() async throws {
        let store = BookmarkStore(storage: InMemoryBookmarkStorage(), resolver: FakeResolver())
        let bookmark = try await store.add(URL(fileURLWithPath: "/Volumes/T7"))
        #expect(try await store.resolve(bookmark).url.path == "/Volumes/T7")
        #expect(await store.bookmarks() == [bookmark])
    }

    @Test func renewsAStaleBookmark() async throws {
        let storage = InMemoryBookmarkStorage()
        let saving = BookmarkStore(storage: storage, resolver: FakeResolver())
        let bookmark = try await saving.add(URL(fileURLWithPath: "/old"))

        let resolving = BookmarkStore(storage: storage, resolver: FakeResolver(stale: true))
        let resolved = try await resolving.resolve(bookmark)
        #expect(resolved.isStale)
        try await resolving.renew(bookmark, for: resolved.url)

        let refreshed = try #require(await resolving.bookmarks().first)
        #expect(refreshed.id == bookmark.id)
        #expect(refreshed.refreshCount == 1)
    }

    /// iOS makes new data only inside the folder's scope, which starts after resolving
    /// (audit 2026-11, A18): resolving leaves the data alone.
    @Test func resolvingAStaleBookmarkMakesNoNewData() async throws {
        let storage = InMemoryBookmarkStorage()
        let bookmark = try await BookmarkStore(storage: storage, resolver: FakeResolver())
            .add(URL(fileURLWithPath: "/old"))

        let resolving = BookmarkStore(
            storage: storage, resolver: FakeResolver(stale: true, cannotRenew: true))
        let resolved = try await resolving.resolve(bookmark)

        #expect(resolved.url.path == "/old")
        #expect(await resolving.bookmarks() == [bookmark])
    }

    @Test func remembersTheFolderNameOfABookmark() async throws {
        let store = BookmarkStore(storage: InMemoryBookmarkStorage(), resolver: FakeResolver())
        let bookmark = try await store.add(URL(fileURLWithPath: "/Volumes/T7/Photos"))
        #expect(bookmark.name == "Photos")
    }

    @Test func readsABookmarkSavedWithoutAName() throws {
        let saved = Data(
            #"[{"id":"7A3B5C2E-1D4F-4A6B-8C9D-0E1F2A3B4C5D","data":"","refreshCount":0}]"#.utf8)
        let bookmarks = try JSONDecoder().decode([Bookmark].self, from: saved)
        #expect(bookmarks.first?.name == nil)
    }

    @Test func keepsBookmarksInItsStorage() async throws {
        let storage = InMemoryBookmarkStorage()
        let bookmark = try await BookmarkStore(storage: storage, resolver: FakeResolver())
            .add(URL(fileURLWithPath: "/a"))
        let reopened = BookmarkStore(storage: storage, resolver: FakeResolver())
        #expect(await reopened.bookmarks() == [bookmark])
    }

    @Test func removesABookmark() async throws {
        let store = BookmarkStore(storage: InMemoryBookmarkStorage(), resolver: FakeResolver())
        let bookmark = try await store.add(URL(fileURLWithPath: "/a"))
        await store.remove(bookmark)
        #expect(await store.bookmarks().isEmpty)
    }

    @Test func makesARealBookmarkThatResolvesToTheFolder() throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("Folder")
        let resolver = SystemBookmarkResolver()
        let (url, _) = try resolver.resolve(try resolver.bookmarkData(for: folder))
        #expect(url.resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path)
    }
}
