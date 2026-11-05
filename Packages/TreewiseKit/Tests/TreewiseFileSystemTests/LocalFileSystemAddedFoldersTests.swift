import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// The folders the user added on iOS (ADR 0045): they are the Locations and
/// the boundary, and nothing outside them is reachable.
@Suite struct LocalFileSystemAddedFoldersTests {
    private func fileSystem(_ folders: [URL], in directory: TempDirectory) -> LocalFileSystem {
        LocalFileSystem(locations: .added(folders, home: directory.url("home")))
    }

    @Test func addedFoldersAreTheLocations() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let work = try directory.makeFolder("Work")

        let locations = try await fileSystem([photos, work], in: directory).locations()

        #expect(locations.map(\.id) == [FileItem.ID(photos.path), FileItem.ID(work.path)])
        #expect(locations.map(\.name) == ["Photos", "Work"])
        #expect(locations.allSatisfy { $0.kind == .folder })
    }

    @Test func anAddedFolderHasNoEnclosingFolder() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let fileSystem = fileSystem([photos], in: directory)

        let item = try await fileSystem.item(at: FileItem.ID(photos.path))

        #expect(item.parentID == nil)
        #expect(try await fileSystem.ancestorIDs(of: item.id).isEmpty)
    }

    @Test func aFolderInsideAnAddedFolderIsReachable() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        try directory.makeFolder("Photos/2026")
        let fileSystem = fileSystem([photos], in: directory)

        let contents = try await fileSystem.contents(of: FileItem.ID(photos.path))

        #expect(contents.map(\.name) == ["2026"])
        #expect(try await fileSystem.ancestorIDs(of: contents[0].id) == [FileItem.ID(photos.path)])
    }

    @Test func nothingOutsideTheAddedFoldersIsReachable() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        try directory.makeFile("Secret.md")
        let fileSystem = fileSystem([photos], in: directory)

        await #expect(throws: FileSystemError.outsideBoundary(FileItem.ID(directory.path))) {
            try await fileSystem.contents(of: FileItem.ID(directory.path))
        }
    }

    @Test func anAddedFolderThatIsGoneIsLeftOut() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let gone = directory.url("Gone")

        let locations = try await fileSystem([gone, photos], in: directory).locations()

        #expect(locations.map(\.id) == [FileItem.ID(photos.path)])
    }

    @Test func anAddedFolderRemovedAfterBeingListedIsLeftOut() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let fileSystem = fileSystem([photos], in: directory)
        _ = try await fileSystem.locations()

        try FileManager.default.removeItem(at: photos)

        #expect(try await fileSystem.locations().isEmpty)
    }

    @Test func noFolderAddedMeansNoLocations() async throws {
        let directory = try TempDirectory()
        #expect(try await fileSystem([], in: directory).locations().isEmpty)
    }

    @Test func favoritesOutsideTheAddedFoldersAreLeftOut() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        try directory.makeFolder("home/Documents")
        #expect(try await fileSystem([photos], in: directory).favorites().isEmpty)
    }

    @Test func favoritesInsideTheBoundaryStay() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        try directory.makeFolder("Volume/Users/Home/Documents")
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("Volume/Users/Home"),
                applications: directory.url("Volume/Applications"),
                mountedVolumes: { [volume] }, boundary: [volume]))
        #expect(try await fileSystem.favorites().map(\.name) == ["Documents"])
    }
}
