import Foundation
import Testing
import TreewiseFileSystem
import TreewiseTestSupport

/// Saving and restoring folder access (PLAN.md §9.3, ADR 0006).
@Suite struct BookmarkStoreTests {
    /// Resolves bookmark data that is just the path, and reports it stale when asked.
    struct FakeResolver: BookmarkResolving {
        var stale = false

        func bookmarkData(for url: URL) throws -> Data {
            Data(url.path.utf8)
        }

        func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
            (URL(fileURLWithPath: String(bytes: data, encoding: .utf8) ?? "/"), stale)
        }
    }

    @Test func restoresAFolderItSaved() async throws {
        let store = BookmarkStore(storage: InMemoryBookmarkStorage(), resolver: FakeResolver())
        let bookmark = try await store.add(URL(fileURLWithPath: "/Volumes/T7"))
        #expect(try await store.resolve(bookmark).path == "/Volumes/T7")
        #expect(await store.bookmarks() == [bookmark])
    }

    @Test func refreshesAStaleBookmarkWhenResolvingIt() async throws {
        let storage = InMemoryBookmarkStorage()
        let saving = BookmarkStore(storage: storage, resolver: FakeResolver())
        let bookmark = try await saving.add(URL(fileURLWithPath: "/old"))

        let resolving = BookmarkStore(storage: storage, resolver: FakeResolver(stale: true))
        _ = try await resolving.resolve(bookmark)

        let refreshed = try #require(await resolving.bookmarks().first)
        #expect(refreshed.id == bookmark.id)
        #expect(refreshed.refreshCount == 1)
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
