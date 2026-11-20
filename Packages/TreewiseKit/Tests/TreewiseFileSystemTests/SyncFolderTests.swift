import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

@testable import TreewiseFileSystem

/// A drive's `.treewise` folder (ADR 0144): each device writes only its own file and reads
/// everyone's; a file that cannot be read is skipped and never written over.
@Suite struct SyncFolderTests {
    private static let at = Date(timeIntervalSince1970: 2_000_000_000)

    private static func record(_ path: String, device: String) -> SyncRecord {
        SyncRecord(
            key: SyncKey(.folder(path), "enabledModules"), value: .array([.string("dates")]),
            changedAt: at, device: device)
    }

    @Test func aDeviceReadsBackItsOwnFile() throws {
        let drive = try TempDirectory()
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        try mac.write([Self.record("Clients", device: "mac")])

        let reading = try mac.read()

        #expect(reading.files.map(\.device) == ["mac"])
        #expect(reading.files.first?.records == [Self.record("Clients", device: "mac")])
        #expect(
            FileManager.default.fileExists(
                atPath: drive.url.appending(path: ".treewise.settings/devices/mac.json").path))
    }

    @Test func eachDeviceReadsTheOthersFile() throws {
        let drive = try TempDirectory()
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        let ipad = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "ipad", name: "iPad"))
        try mac.write([Self.record("Clients", device: "mac")])
        try ipad.write([Self.record("Photos", device: "ipad")])

        let files = try mac.read().files

        #expect(Set(files.map(\.device)) == ["mac", "ipad"])
        #expect(files.first { $0.device == "ipad" }?.name == "iPad")
    }

    @Test func aFolderWithoutTreewiseReadsAsNothing() throws {
        let drive = try TempDirectory()
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        #expect(try mac.read().files.isEmpty)
    }

    @Test func anUnreadableFileIsSkippedAndTheRestRead() throws {
        let drive = try TempDirectory()
        _ = try drive.makeFolder(".treewise.settings/devices")
        _ = try drive.makeFile(".treewise.settings/devices/broken.json", contents: "not json")
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        try mac.write([Self.record("Clients", device: "mac")])

        let reading = try mac.read()

        #expect(reading.files.map(\.device) == ["mac"])
        #expect(reading.skipped.map(\.lastPathComponent) == ["broken.json"])
    }

    @Test func itsOwnFileOfANewerFormatIsNotWrittenOver() throws {
        let drive = try TempDirectory()
        let newer = #"{"format": 99, "device": "mac", "name": "Mac", "records": []}"#
        _ = try drive.makeFolder(".treewise.settings/devices")
        let own = try drive.makeFile(".treewise.settings/devices/mac.json", contents: newer)
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))

        #expect(throws: DeviceSyncFile.Problem.newerFormat(99)) {
            try mac.write([Self.record("Clients", device: "mac")])
        }
        #expect(try String(contentsOf: own, encoding: .utf8) == newer)
    }

    @Test func aFileThatIsNotADevicesIsLeftAlone() throws {
        let drive = try TempDirectory()
        _ = try drive.makeFolder(".treewise.settings/devices")
        _ = try drive.makeFile(".treewise.settings/devices/notes.txt", contents: "hello")
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        #expect(try mac.read().skipped.isEmpty)
    }

    // MARK: - Which folder (ADR 0144)

    @Test func aDeviceThatMakesNoFolderWaitsAndWritesNothing() throws {
        let drive = try TempDirectory()
        let ipad = SyncFolder(
            driveRoot: drive.url, device: SyncDevice(id: "ipad", name: "iPad"), making: .none)
        #expect(throws: SyncFolder.Problem.notStarted) {
            try ipad.write([Self.record("Clients", device: "ipad")])
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: drive.path).isEmpty)
        #expect(try ipad.read().files.isEmpty)
    }

    @Test func aDeviceUsesTheHiddenFolderAMacMade() throws {
        let drive = try TempDirectory()
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        try mac.write([Self.record("Clients", device: "mac")])
        let ipad = SyncFolder(
            driveRoot: drive.url, device: SyncDevice(id: "ipad", name: "iPad"), making: .none)

        try ipad.write([Self.record("Photos", device: "ipad")])

        #expect(Set(try ipad.read().files.map(\.device)) == ["mac", "ipad"])
        #expect(
            FileManager.default.fileExists(
                atPath: drive.url.appending(path: ".treewise.settings/devices/ipad.json").path))
    }

    @Test func anIPadAskedMakesTheVisibleFolderAndAMacJoinsIt() throws {
        let drive = try TempDirectory()
        let ipad = SyncFolder(
            driveRoot: drive.url, device: SyncDevice(id: "ipad", name: "iPad"), making: .visible)
        try ipad.write([Self.record("Photos", device: "ipad")])
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))

        try mac.write([Self.record("Clients", device: "mac")])

        #expect(
            FileManager.default.fileExists(
                atPath: drive.url.appending(path: "treewise.settings/devices/mac.json").path))
        #expect(
            !FileManager.default.fileExists(
                atPath: drive.url.appending(path: ".treewise.settings").path),
            "the Mac makes no second folder")
    }

    @Test func theHiddenFolderComesFirstWhenBothAreThere() throws {
        let drive = try TempDirectory()
        _ = try drive.makeFolder("treewise.settings/devices")
        _ = try drive.makeFolder(".treewise.settings/devices")
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        try mac.write([Self.record("Clients", device: "mac")])
        #expect(
            FileManager.default.fileExists(
                atPath: drive.url.appending(path: ".treewise.settings/devices/mac.json").path))
    }

    @Test func theDevicesFilesOfBothFoldersAreRead() throws {
        let drive = try TempDirectory()
        let ipad = SyncFolder(
            driveRoot: drive.url, device: SyncDevice(id: "ipad", name: "iPad"), making: .visible)
        try ipad.write([Self.record("Photos", device: "ipad")])
        _ = try drive.makeFolder(".treewise.settings/devices")
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        try mac.write([Self.record("Clients", device: "mac")])

        #expect(Set(try mac.read().files.map(\.device)) == ["mac", "ipad"])
    }

    @Test func hidingRenamesTheVisibleFolder() throws {
        let drive = try TempDirectory()
        let ipad = SyncFolder(
            driveRoot: drive.url, device: SyncDevice(id: "ipad", name: "iPad"), making: .visible)
        try ipad.write([Self.record("Photos", device: "ipad")])
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))
        #expect(mac.usesVisibleFolder())

        let trashed = try mac.hideFolder()

        #expect(trashed == nil, "nothing to throw away")
        #expect(!mac.usesVisibleFolder())
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: drive.path) == [
                ".treewise.settings"
            ])
        #expect(try mac.read().files.map(\.device) == ["ipad"])
    }

    @Test func hidingWhereBothAreThereMovesTheFilesAndTrashesTheVisibleOne() throws {
        let drive = try TempDirectory()
        let ipad = SyncFolder(
            driveRoot: drive.url, device: SyncDevice(id: "ipad", name: "iPad"), making: .visible)
        try ipad.write([Self.record("Photos", device: "ipad")])
        _ = try drive.makeFolder(".treewise.settings/devices")
        let mac = SyncFolder(driveRoot: drive.url, device: SyncDevice(id: "mac", name: "Mac"))

        let trashed = try mac.hideFolder()
        defer { if let trashed { try? TrashService().restore(trashed) } }

        #expect(trashed != nil)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: drive.path) == [
                ".treewise.settings"
            ])
        #expect(
            FileManager.default.fileExists(
                atPath: drive.url.appending(path: ".treewise.settings/devices/ipad.json").path))
    }

    @Test(arguments: [
        ("/Drive", "/Drive/Clients/2026", "Clients/2026"),
        ("/Drive", "/Drive", ""),
        ("/Drive/", "/Drive/Clients", "Clients"),
    ])
    func aFolderInTheDriveHasItsPathFromTheRoot(root: String, folder: String, path: String) {
        #expect(SyncFolder.path(of: folder, inDriveAt: root) == path)
    }

    @Test(arguments: [("/Drive", "/Drive 2/Clients"), ("/Drive", "/Other")])
    func aFolderOutsideTheDriveHasNone(root: String, folder: String) {
        #expect(SyncFolder.path(of: folder, inDriveAt: root) == nil)
    }
}

/// The device's id, made once per installation (ADR 0144).
@Suite struct SyncDeviceTests {
    @Test func theIDIsMadeOnceAndKept() throws {
        let support = try TempDirectory()
        let first = SyncDevice.load(from: support.url, name: "Mac")
        let again = SyncDevice.load(from: support.url, name: "Mac")
        #expect(!first.id.isEmpty)
        #expect(first.id == again.id)
    }

    @Test func anotherInstallationHasAnotherID() throws {
        let one = try TempDirectory()
        let other = try TempDirectory()
        #expect(
            SyncDevice.load(from: one.url, name: "Mac").id
                != SyncDevice.load(from: other.url, name: "Mac").id)
    }
}
