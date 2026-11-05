import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// This Mac, the location that holds the volumes (ADR 0044), with volumes
/// faked by folders inside a TempDirectory.
@Suite struct LocalFileSystemThisMacTests {
    private func fileSystem(
        in directory: TempDirectory, volumes: [URL], boundary: [URL]? = nil
    ) -> LocalFileSystem {
        LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                mountedVolumes: { volumes }, boundary: boundary))
    }

    @Test func thisMacListsTheLocations() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        let fileSystem = fileSystem(in: directory, volumes: [volume])

        let contents = try await fileSystem.contents(of: .computer)

        #expect(contents == (try await fileSystem.locations()))
        #expect(contents.map(\.id) == [FileItem.ID(volume.path)])
    }

    @Test func thisMacIsAnItemOfItsOwn() async throws {
        let directory = try TempDirectory()
        let thisMac = try await fileSystem(in: directory, volumes: []).item(at: .computer)
        #expect(thisMac.kind == .computer)
        #expect(thisMac.parentID == nil)
    }

    @Test func thisMacIsInsideTheBoundary() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        let fileSystem = fileSystem(in: directory, volumes: [volume], boundary: [volume])
        #expect(try await fileSystem.item(at: .computer).kind == .computer)
        #expect(try await fileSystem.contents(of: .computer).count == 1)
    }

    @Test func thisMacHasNoFreeSpaceOfItsOwn() async throws {
        let directory = try TempDirectory()
        let fileSystem = fileSystem(in: directory, volumes: [])
        #expect(try await fileSystem.availableCapacity(of: .computer) == nil)
    }

    @Test func volumesAreInThisMac() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        let locations = try await fileSystem(in: directory, volumes: [volume]).locations()
        #expect(locations.first?.parentID == .computer)
    }

    @Test func aVolumeThatLeftIsLeftOut() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        let gone = directory.url("Ejected")
        let locations = try await fileSystem(in: directory, volumes: [volume, gone]).locations()
        #expect(locations.map(\.id) == [FileItem.ID(volume.path)])
    }

    @Test func aVolumeEjectedAfterBeingListedIsLeftOut() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        let fileSystem = fileSystem(in: directory, volumes: [volume])
        _ = try await fileSystem.locations()

        try FileManager.default.removeItem(at: volume)

        #expect(try await fileSystem.locations().isEmpty)
    }

    @Test func aFolderInAVolumeIsNotInThisMac() async throws {
        let directory = try TempDirectory()
        let volume = try directory.makeFolder("Volume")
        try directory.makeFolder("Volume/Projects")
        let fileSystem = fileSystem(in: directory, volumes: [volume], boundary: [volume])
        let projects = try await fileSystem.item(at: FileItem.ID(volume.path + "/Projects"))
        #expect(projects.parentID == FileItem.ID(volume.path))
    }
}
