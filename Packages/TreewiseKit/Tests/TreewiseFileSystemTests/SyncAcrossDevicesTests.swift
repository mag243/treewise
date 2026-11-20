import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseTestSupport

@testable import TreewiseFileSystem

/// Two devices syncing through one drive (ADR 0144, M11's acceptance): each with its own
/// stores, sharing only the drive's folder.
@Suite struct SyncAcrossDevicesTests {
    /// One device: its support folder, stores and session; the shared drive's root.
    private struct Device {
        let folders: FolderSettingsStore
        let templates: FolderTemplateStore
        let session: SyncSession
        let clock: Clock
        /// Kept so its folder lasts as long as the device.
        let support: TempDirectory

        init(_ id: String, drive: URL, support: TempDirectory, clock: Clock) {
            self.support = support
            folders = FolderSettingsStore(directory: support.url)
            templates = FolderTemplateStore(directory: support.url.appending(path: "Templates"))
            self.clock = clock
            let sync = SettingsSync(device: SyncDevice(id: id, name: id), now: { clock.now })
            session = SyncSession(sync: sync, folders: folders, templates: templates)
        }
    }

    /// A clock the test moves on.
    private final class Clock: Sendable {
        private let time = Mutex(Date(timeIntervalSince1970: 2_000_000_000))
        var now: Date { time.withLock { $0 } }
        func advance(_ seconds: TimeInterval = 60) {
            time.withLock { $0 = $0.addingTimeInterval(seconds) }
        }
    }

    private static func settings(_ module: String) -> FolderSettings {
        FolderSettings(enabledModules: [module], templates: [:])
    }

    /// Two devices and their drive.
    private struct Pair {
        let mac: Device
        let ipad: Device
        let drive: TempDirectory
    }

    private static func pair() throws -> Pair {
        let drive = try TempDirectory()
        let clock = Clock()
        return Pair(
            mac: Device("a-mac", drive: drive.url, support: try TempDirectory(), clock: clock),
            ipad: Device("b-ipad", drive: drive.url, support: try TempDirectory(), clock: clock),
            drive: drive)
    }

    @Test func aFolderSettingMadeOnOneDeviceIsThereOnTheOther() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients/2026").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)

        await mac.folders.save(Self.settings("dates"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.refresh()

        #expect(await ipad.folders.settings(forFolderAt: folder) == Self.settings("dates"))
    }

    @Test func aTemplateMadeOnOneDeviceIsThereOnTheOther() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        let template = FolderTemplate(id: "t1", name: "Year", root: FolderTree(name: "{year}"))

        try await mac.templates.save(template)
        await mac.session.settle()
        await ipad.session.refresh()

        #expect(await ipad.templates.templates() == [template])
    }

    @Test func aRemovalOnOneDeviceRemovesOnTheOther() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(Self.settings("dates"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.refresh()

        mac.clock.advance()
        await ipad.folders.clearAll()
        await ipad.session.settle()
        await mac.session.refresh()

        #expect(await mac.folders.settings(forFolderAt: folder) == nil)
    }

    @Test func changesOnBothAtOnceKeepTheNewerAndMakeNoConflictFile() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)

        await mac.folders.save(Self.settings("older"), forFolderAt: folder)
        mac.clock.advance()
        await ipad.folders.save(Self.settings("newer"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.settle()
        await mac.session.refresh()
        await ipad.session.refresh()

        #expect(await mac.folders.settings(forFolderAt: folder) == Self.settings("newer"))
        #expect(await ipad.folders.settings(forFolderAt: folder) == Self.settings("newer"))
        let files = try FileManager.default.contentsOfDirectory(
            atPath: drive.url.appending(path: ".treewise/devices").path)
        #expect(Set(files) == ["a-mac.json", "b-ipad.json"])
    }

    @Test func aChangeTakenOverIsNotRecordedAgain() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(Self.settings("dates"), forFolderAt: folder)
        await mac.session.settle()

        await ipad.session.refresh()
        await ipad.session.settle()

        let ipadFile = try DeviceSyncFile.decoded(
            from: Data(contentsOf: drive.url.appending(path: ".treewise/devices/b-ipad.json")))
        #expect(ipadFile.records.isEmpty, "the iPad stamps nothing of the Mac's")
    }

    @Test func aDeviceLateToStartDoesNotOverwriteNewerChanges() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        await ipad.folders.save(Self.settings("stale"), forFolderAt: folder)
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(Self.settings("fresh"), forFolderAt: folder)
        await mac.session.settle()

        mac.clock.advance()
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.session.refresh()

        #expect(await ipad.folders.settings(forFolderAt: folder) == Self.settings("fresh"))
        #expect(await mac.folders.settings(forFolderAt: folder) == Self.settings("fresh"))
    }

    @Test func aMoveByTreewiseTakesTheSettingsAlong() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let old = try drive.makeFolder("Clients/Acme").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(Self.settings("dates"), forFolderAt: old)
        await mac.session.settle()
        await ipad.session.refresh()

        mac.clock.advance()
        let new = try drive.moveFolder(atPath: old, to: "Acme Ltd")
        await mac.folders.folderMoved(from: old, to: new)
        await mac.session.settle()
        await ipad.session.refresh()

        #expect(await ipad.folders.settings(forFolderAt: new) == Self.settings("dates"))
    }

    @Test func withSyncOffNothingIsWrittenInTheDrive() async throws {
        let pair = try Self.pair()
        let (mac, drive) = (pair.mac, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        await mac.session.stop()

        await mac.folders.save(Self.settings("dates"), forFolderAt: folder)
        await mac.session.settle()

        let own = drive.url.appending(path: ".treewise/devices/a-mac.json")
        let records =
            (try? DeviceSyncFile.decoded(from: Data(contentsOf: own)))?.records ?? []
        #expect(records.isEmpty)
        #expect(await mac.folders.settings(forFolderAt: folder) == Self.settings("dates"))
    }

    @Test func theSavedPatternsChangedOnOneDeviceAreHandedToTheOthersApp() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        _ = await mac.session.start(drives: [drive.url], patterns: .examples())
        let theirs = await ipad.session.start(drives: [drive.url], patterns: .examples())
        #expect(theirs.isEmpty, "the examples on both: nothing to take over")

        var changed = SavedPatterns.examples()
        _ = changed.save(name: "Receipts", text: "{date} Receipt")
        mac.clock.advance()
        await mac.session.patternsChanged(changed)

        #expect(await ipad.session.refresh() == [.savedPatterns(changed)])
    }

    @Test func aDevicesOwnPatternsWinOverAnotherStartingWithTheExamples() async throws {
        let pair = try Self.pair()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        _ = await ipad.session.start(drives: [drive.url], patterns: .examples())
        var own = SavedPatterns.examples()
        _ = own.save(name: "Receipts", text: "{date} Receipt")

        _ = await mac.session.start(drives: [drive.url], patterns: own)

        #expect(await ipad.session.refresh() == [.savedPatterns(own)])
    }
}
