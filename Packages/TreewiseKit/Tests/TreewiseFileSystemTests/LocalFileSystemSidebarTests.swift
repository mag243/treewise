import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Favorites, locations and free space, from folders inside a TempDirectory.
@Suite struct LocalFileSystemSidebarTests {
    @Test func listsTheFavoritesThatExist() async throws {
        let directory = try TempDirectory()
        for folder in [
            "Applications", "home/Desktop", "home/Documents", "home/Downloads", "home/Pictures",
        ] {
            try directory.makeFolder(folder)
        }
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))

        let names = try await fileSystem.favorites().map(\.name)

        #expect(names == ["Applications", "Desktop", "Documents", "Downloads", "Pictures"])
    }

    @Test func leavesOutTheFavoritesThatDoNotExist() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home/Documents")
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))
        #expect(try await fileSystem.favorites().map(\.name) == ["Documents"])
    }

    @Test func listsTheMountedVolumesAndICloudDrive() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        try directory.makeFolder("home/Library/Mobile Documents/com~apple~CloudDocs")
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                mountedVolumes: { [volume] }))

        let locations = try await fileSystem.locations()

        #expect(locations.map(\.kind) == [.volume, .home, .cloud])
        #expect(locations.first?.id == FileItem.ID(volume.path))
        #expect(locations.last?.name == "iCloud Drive")
    }

    @Test func listsTheHomeFolderAsALocationUnderItsOwnName() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home")
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                mountedVolumes: { [] }))

        let locations = try await fileSystem.locations()

        #expect(locations.map(\.name) == ["home"])
        #expect(locations.map(\.kind) == [.home])
    }

    @Test func leavesOutICloudDriveWhenItIsNotThere() async throws {
        let directory = try TempDirectory()
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                mountedVolumes: { [] }))
        #expect(try await fileSystem.locations().isEmpty)
    }

    @Test func reportsTheFreeSpaceOfAFoldersVolume() async throws {
        let directory = try TempDirectory()
        let fileSystem = LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))
        let free = try await fileSystem.availableCapacity(of: FileItem.ID(directory.path))
        #expect((free ?? 0) > 0)
    }
}
