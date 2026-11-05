import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// The cloud folders among the Locations, from folders inside a TempDirectory (ADR 0049).
@Suite struct LocalFileSystemCloudFoldersTests {
    private func fileSystem(
        in directory: TempDirectory, boundary: [URL]? = nil
    ) -> LocalFileSystem {
        LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                mountedVolumes: { [] }, boundary: boundary))
    }

    /// The cloud rows of the Locations, without the home folder beside them.
    private func cloudLocations(in directory: TempDirectory) async throws -> [FileItem] {
        try await fileSystem(in: directory).locations().filter { $0.kind == .cloud }
    }

    @Test func listsTheFoldersInCloudStorageAsCloudLocations() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home/Library/CloudStorage/Dropbox")

        let locations = try await cloudLocations(in: directory)

        #expect(locations.map(\.name) == ["Dropbox"])
    }

    @Test(arguments: ["Dropbox", "Nextcloud"])
    func listsASyncFolderInTheHomeFolder(name: String) async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home/\(name)")

        let locations = try await cloudLocations(in: directory)

        #expect(locations.map(\.name) == [name])
    }

    @Test func listsAfterICloudDriveSortedByName() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home/Library/Mobile Documents/com~apple~CloudDocs")
        try directory.makeFolder("home/Nextcloud")
        try directory.makeFolder("home/Library/CloudStorage/Dropbox")

        let names = try await cloudLocations(in: directory).map(\.name)

        #expect(names == ["iCloud Drive", "Dropbox", "Nextcloud"])
    }

    @Test func separatesTheServiceFromTheAccountInTheName() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home/Library/CloudStorage/OneDrive-Personal")
        try directory.makeFolder("home/Library/CloudStorage/Nextcloud-me@cloud-host.example")

        let names = try await cloudLocations(in: directory).map(\.name)

        #expect(names == ["Nextcloud - me@cloud-host.example", "OneDrive - Personal"])
    }

    @Test func leavesOutWhatIsNotAVisibleFolder() async throws {
        let directory = try TempDirectory()
        let storage = try directory.makeFolder("home/Library/CloudStorage")
        try directory.makeFolder("home/Library/CloudStorage/.hidden")
        try Data().write(to: storage.appendingPathComponent("notes.txt"))

        #expect(try await cloudLocations(in: directory).isEmpty)
    }

    @Test func leavesOutASymlinkInTheHomeFolder() async throws {
        let directory = try TempDirectory()
        let target = try directory.makeFolder("home/Library/CloudStorage/Dropbox")
        try FileManager.default.createSymbolicLink(
            at: directory.url("home/Dropbox"), withDestinationURL: target)

        let locations = try await cloudLocations(in: directory)

        #expect(locations.map(\.id) == [FileItem.ID(target.standardizedFileURL.path)])
    }

    @Test func leavesOutWhatIsOutsideTheBoundary() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        try directory.makeFolder("home/Dropbox")

        #expect(try await fileSystem(in: directory, boundary: [volume]).locations().isEmpty)
    }

    /// A provider where every file asked about is only online.
    private func onlyOnline(in directory: TempDirectory) -> LocalFileSystem {
        LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                mountedVolumes: { [] }, isOnlyOnline: { _ in true }))
    }

    @Test func aListingInACloudFolderReadsTheCloudStatus() async throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("home/Library/CloudStorage/Dropbox/Work")
        try directory.makeFile("home/Library/CloudStorage/Dropbox/Work/report.pdf")

        let contents = try await onlyOnline(in: directory).contents(
            of: FileItem.ID(folder.standardizedFileURL.path))

        #expect(contents.map(\.isOnlyOnline) == [true])
    }

    @Test func aFileInACloudFolderReportsItsStatusWhenReadAlone() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("home/Nextcloud")
        let file = try directory.makeFile("home/Nextcloud/report.pdf")

        let item = try await onlyOnline(in: directory).item(
            at: FileItem.ID(file.standardizedFileURL.path))

        #expect(item.isOnlyOnline)
    }

    @Test func aFolderInACloudFolderHasNoCloudStatus() async throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("home/Dropbox")
        try directory.makeFolder("home/Dropbox/Work")

        let contents = try await onlyOnline(in: directory).contents(
            of: FileItem.ID(folder.standardizedFileURL.path))

        #expect(contents.map(\.isOnlyOnline) == [false])
    }

    @Test func outsideACloudFolderTheStatusIsNotRead() async throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("home/Documents")
        try directory.makeFile("home/Documents/report.pdf")

        let contents = try await onlyOnline(in: directory).contents(
            of: FileItem.ID(folder.standardizedFileURL.path))

        #expect(contents.map(\.isOnlyOnline) == [false])
    }

    @Test func aFileOnDiskIsNotOnlyOnline() throws {
        let directory = try TempDirectory()
        let file = try directory.makeFile("report.pdf")
        #expect(!LocalFileSystem.Locations.systemIsOnlyOnline(file))
    }

    @Test func aListingShowsACloudFolderAsACloudLocation() async throws {
        let directory = try TempDirectory()
        let home = try directory.makeFolder("home")
        try directory.makeFolder("home/Nextcloud")
        try directory.makeFolder("home/Projects")
        let fileSystem = fileSystem(in: directory)

        let contents = try await fileSystem.contents(
            of: FileItem.ID(home.standardizedFileURL.path))

        #expect(contents.first { $0.name == "Nextcloud" }?.kind == .cloud)
        #expect(contents.first { $0.name == "Projects" }?.kind == .folder)
    }
}
