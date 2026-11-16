import Foundation
import Testing
import TreewiseFileSystem
import TreewiseTestSupport

/// The folders the user added on iOS, kept as bookmarks between launches (ADR 0045).
@Suite struct AddedFoldersTests {
    private func folders(in directory: TempDirectory) -> AddedFolders {
        AddedFolders(
            store: BookmarkStore(
                storage: FileBookmarkStorage(file: directory.url("Support/locations.json"))))
    }

    /// The real paths of folders, as a resolved bookmark may name the
    /// temporary directory through `/private`.
    private func paths(_ folders: [URL]) -> [String] {
        folders.map { $0.resolvingSymlinksInPath().path }
    }

    @Test func anAddedFolderIsListed() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let added = folders(in: directory)

        try await added.add(photos)

        #expect(paths(await added.folders()) == paths([photos]))
    }

    @Test func addedFoldersAreFoundAgainAfterARelaunch() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let work = try directory.makeFolder("Work")
        try await folders(in: directory).add(photos)
        try await folders(in: directory).add(work)

        let relaunched = folders(in: directory)
        await relaunched.load()

        #expect(paths(await relaunched.folders()) == paths([photos, work]))
    }

    @Test func aFolderAddedTwiceIsListedOnce() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let added = folders(in: directory)

        try await added.add(photos)
        try await added.add(photos)

        #expect(await added.folders().count == 1)
    }

    @Test func aRemovedFolderLeaves() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let work = try directory.makeFolder("Work")
        let added = folders(in: directory)
        try await added.add(photos)
        try await added.add(work)

        await added.remove(photos)

        #expect(paths(await added.folders()) == paths([work]))
        let relaunched = folders(in: directory)
        await relaunched.load()
        #expect(paths(await relaunched.folders()) == paths([work]))
    }

    @Test func aFolderThatNoLongerResolvesIsLeftOut() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let work = try directory.makeFolder("Work")
        try await folders(in: directory).add(photos)
        try await folders(in: directory).add(work)
        try FileManager.default.removeItem(at: photos)

        let relaunched = folders(in: directory)
        await relaunched.load()

        #expect(paths(await relaunched.folders()) == paths([work]))
    }

    /// A stale bookmark whose data cannot be made again, as iOS refuses outside the folder's
    /// scope, keeps its folder (audit 2026-11, A18).
    @Test func aStaleBookmarkThatCannotBeRenewedKeepsItsFolder() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let storage = InMemoryBookmarkStorage()
        try await AddedFolders(
            store: BookmarkStore(storage: storage, resolver: BookmarkStoreTests.FakeResolver())
        ).add(photos)

        let relaunched = AddedFolders(
            store: BookmarkStore(
                storage: storage,
                resolver: BookmarkStoreTests.FakeResolver(stale: true, cannotRenew: true)))
        await relaunched.load()

        #expect(paths(await relaunched.folders()) == paths([photos]))
    }

    /// A folder that is gone, or on a drive not attached, is kept and named, so the sidebar
    /// can offer to connect it again (ADR 0111).
    @Test func aFolderThatIsGoneIsListedAsUnavailableByName() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        try await folders(in: directory).add(photos)
        try FileManager.default.removeItem(at: photos)

        let relaunched = folders(in: directory)
        await relaunched.load()

        #expect(await relaunched.unavailable().map(\.name) == ["Photos"])
    }

    @Test func reconnectingPutsThePickedFolderInPlaceOfTheUnavailableOne() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        try await folders(in: directory).add(photos)
        try FileManager.default.removeItem(at: photos)
        let relaunched = folders(in: directory)
        await relaunched.load()
        let gone = try #require(await relaunched.unavailable().first)
        let found = try directory.makeFolder("Photos Again")

        try await relaunched.reconnect(gone, to: found)

        #expect(paths(await relaunched.folders()) == paths([found]))
        #expect(await relaunched.unavailable().isEmpty)
        let again = folders(in: directory)
        await again.load()
        #expect(paths(await again.folders()) == paths([found]), "only the new one is kept")
    }

    @Test func aForgottenUnavailableFolderStaysGone() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        try await folders(in: directory).add(photos)
        try FileManager.default.removeItem(at: photos)
        let relaunched = folders(in: directory)
        await relaunched.load()
        let gone = try #require(await relaunched.unavailable().first)

        await relaunched.forget(gone)

        #expect(await relaunched.unavailable().isEmpty)
        let again = folders(in: directory)
        await again.load()
        #expect(await again.unavailable().isEmpty)
    }

    @Test func storageWithoutAFileHoldsNoBookmarks() throws {
        let directory = try TempDirectory()
        #expect(FileBookmarkStorage(file: directory.url("missing.json")).load().isEmpty)
    }
}
