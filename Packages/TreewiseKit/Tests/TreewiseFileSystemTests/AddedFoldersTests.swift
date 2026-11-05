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

    @Test func storageWithoutAFileHoldsNoBookmarks() throws {
        let directory = try TempDirectory()
        #expect(FileBookmarkStorage(file: directory.url("missing.json")).load().isEmpty)
    }
}
