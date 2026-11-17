import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// An added folder's own name, and the cloud folders the system reports
/// (ADR 0119).
@Suite struct AddedFolderLabelTests {
    private func folders(in directory: TempDirectory) -> AddedFolders {
        AddedFolders(
            store: BookmarkStore(
                storage: FileBookmarkStorage(file: directory.url("Support/locations.json"))))
    }

    @Test func aLabelIsFoundAgainAfterARelaunch() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("1B4E28BA-2FA1-11D2-883F-0016D3CCA427")
        let added = folders(in: directory)
        try await added.add(photos)

        await added.setLabel("Dropbox", of: photos)

        let relaunched = folders(in: directory)
        await relaunched.load()
        let bookmark = try #require(await relaunched.bookmark(of: photos))
        #expect(bookmark.label == "Dropbox")
    }

    @Test func anEmptyLabelGivesTheFolderItsOwnNameBack() async throws {
        let directory = try TempDirectory()
        let photos = try directory.makeFolder("Photos")
        let added = folders(in: directory)
        try await added.add(photos)
        await added.setLabel("Pictures", of: photos)

        await added.setLabel(nil, of: photos)

        #expect(await added.bookmark(of: photos)?.label == nil)
    }

    @Test func readsABookmarkSavedWithoutALabel() throws {
        let saved = Data(
            #"[{"id":"7A3B5C2E-1D4F-4A6B-8C9D-0E1F2A3B4C5D","data":"","refreshCount":0,"name":"A"}]"#
                .utf8)
        let bookmark = try #require(try JSONDecoder().decode([Bookmark].self, from: saved).first)
        #expect(bookmark.label == nil)
    }

    @Test func anAddedFolderGoesByItsLabel() async throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("1B4E28BA-2FA1-11D2-883F-0016D3CCA427")
        let fileSystem = LocalFileSystem(
            locations: .added(
                [folder], home: directory.url("home"), labels: [folder: "Dropbox"]))

        let locations = try await fileSystem.locations()

        #expect(locations.map(\.name) == ["Dropbox"])
        #expect(try await fileSystem.item(at: locations[0].id).name == "Dropbox")
    }

    @Test func anAddedFolderTheSystemKeepsInTheCloudIsACloudLocation() async throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("Cloud")
        try directory.makeFile("Cloud/Online.pdf")
        try directory.makeFile("Cloud/Here.pdf")
        var locations = LocalFileSystem.Locations.added([folder], home: directory.url("home"))
        locations.isInCloud = { $0.standardizedFileURL == folder.standardizedFileURL }
        locations.isOnlyOnline = { $0.lastPathComponent == "Online.pdf" }
        let fileSystem = LocalFileSystem(locations: locations)

        let location = try #require(try await fileSystem.locations().first)
        let files = try await fileSystem.contents(of: location.id)

        #expect(location.kind == .cloud)
        #expect(files.filter(\.isOnlyOnline).map(\.name) == ["Online.pdf"])
    }

    @Test func anAddedFolderOnThisDeviceIsAPlainFolder() async throws {
        let directory = try TempDirectory()
        let folder = try directory.makeFolder("Photos")
        try directory.makeFile("Photos/Here.pdf")
        let fileSystem = LocalFileSystem(
            locations: .added([folder], home: directory.url("home")))

        let location = try #require(try await fileSystem.locations().first)

        #expect(location.kind == .folder)
        #expect(try await fileSystem.contents(of: location.id).allSatisfy { !$0.isOnlyOnline })
    }

    @Test(arguments: [
        ("/private/var/mobile/Containers/Shared/AppGroup/F00D/File Provider Storage", true),
        ("/var/mobile/Containers/Shared/AppGroup/F00D/File Provider Storage", true),
        ("/var/mobile/Containers/Shared/AppGroup/F00D/File Provider Storage/Downloads", false),
        ("/Users/someone/File Provider Storage", false),
    ])
    func onMyIPadIsKnownByItsPlace(path: String, isFolder: Bool) {
        #expect(
            LocalFileSystem.Locations.isOnMyDeviceFolder(URL(fileURLWithPath: path)) == isFolder)
    }
}
