import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

@testable import TreewiseFileSystem

/// Two devices syncing through one drive (ADR 0144, M11's acceptance): each with its own
/// stores, sharing only the drive's folder.
@Suite struct SyncAcrossDevicesTests {
    @Test func aFolderSettingMadeOnOneDeviceIsThereOnTheOther() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients/2026").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)

        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.refresh()

        #expect(await ipad.folders.settings(forFolderAt: folder) == SyncTestPair.settings("dates"))
    }

    @Test func aTemplateMadeOnOneDeviceIsThereOnTheOther() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        let template = FolderTemplate(id: "t1", name: "Year", root: FolderTree(name: "{year}"))

        try await mac.templates.save(template)
        await mac.session.settle()
        await ipad.session.refresh()

        #expect(await ipad.templates.templates() == [template.withFolderIDs()])
    }

    @Test func aRemovalOnOneDeviceRemovesOnTheOther() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.refresh()

        mac.clock.advance()
        await ipad.folders.clearAll()
        await ipad.session.settle()
        await mac.session.refresh()

        #expect(await mac.folders.settings(forFolderAt: folder) == nil)
    }

    @Test func changesOnBothAtOnceKeepTheNewerAndMakeNoConflictFile() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)

        await mac.folders.save(SyncTestPair.settings("older"), forFolderAt: folder)
        mac.clock.advance()
        await ipad.folders.save(SyncTestPair.settings("newer"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.settle()
        await mac.session.refresh()
        await ipad.session.refresh()

        #expect(await mac.folders.settings(forFolderAt: folder) == SyncTestPair.settings("newer"))
        #expect(await ipad.folders.settings(forFolderAt: folder) == SyncTestPair.settings("newer"))
        let files = try FileManager.default.contentsOfDirectory(
            atPath: drive.url.appending(path: ".treewise.settings/devices").path)
        #expect(Set(files) == ["a-mac.json", "b-ipad.json"])
    }

    @Test func aChangeTakenOverIsNotRecordedAgain() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: folder)
        await mac.session.settle()

        await ipad.session.refresh()
        await ipad.session.settle()

        let ipadFile = try DeviceSyncFile.decoded(
            from: Data(
                contentsOf: drive.url.appending(path: ".treewise.settings/devices/b-ipad.json")))
        #expect(ipadFile.records.isEmpty, "the iPad stamps nothing of the Mac's")
    }

    @Test func aDeviceLateToStartDoesNotOverwriteNewerChanges() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        await ipad.folders.save(SyncTestPair.settings("stale"), forFolderAt: folder)
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(SyncTestPair.settings("fresh"), forFolderAt: folder)
        await mac.session.settle()

        mac.clock.advance()
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.session.refresh()

        #expect(await ipad.folders.settings(forFolderAt: folder) == SyncTestPair.settings("fresh"))
        #expect(await mac.folders.settings(forFolderAt: folder) == SyncTestPair.settings("fresh"))
    }

    @Test func aMoveByTreewiseTakesTheSettingsAlong() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let old = try drive.makeFolder("Clients/Acme").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: old)
        await mac.session.settle()
        await ipad.session.refresh()

        mac.clock.advance()
        let new = try drive.moveFolder(atPath: old, to: "Acme Ltd")
        await mac.folders.folderMoved(from: old, to: new)
        await mac.session.settle()
        await ipad.session.refresh()

        #expect(await ipad.folders.settings(forFolderAt: new) == SyncTestPair.settings("dates"))
    }

    @Test func withSyncOffNothingIsWrittenInTheDrive() async throws {
        let pair = try SyncTestPair.make()
        let (mac, drive) = (pair.mac, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        await mac.session.stop()

        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: folder)
        await mac.session.settle()

        let own = drive.url.appending(path: ".treewise.settings/devices/a-mac.json")
        let records =
            (try? DeviceSyncFile.decoded(from: Data(contentsOf: own)))?.records ?? []
        #expect(records.isEmpty)
        #expect(await mac.folders.settings(forFolderAt: folder) == SyncTestPair.settings("dates"))
    }

    @Test func theSavedPatternsChangedOnOneDeviceAreHandedToTheOthersApp() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        _ = await mac.session.start(drives: [drive.url], patterns: .examples())
        let theirs = await ipad.session.start(drives: [drive.url], patterns: .examples())
        #expect(theirs.isEmpty, "the examples on both: nothing to take over")

        var changed = SavedPatterns.examples()
        _ = changed.save(name: "Receipts", text: "{date} Receipt")
        mac.clock.advance()
        await mac.session.patternsChanged(from: .examples(), to: changed)

        #expect(await ipad.session.refresh() == [.savedPatterns(changed)])
    }

    @Test func aDevicesOwnPatternsWinOverAnotherStartingWithTheExamples() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        _ = await ipad.session.start(drives: [drive.url], patterns: .examples())
        var own = SavedPatterns.examples()
        _ = own.save(name: "Receipts", text: "{date} Receipt")

        _ = await mac.session.start(drives: [drive.url], patterns: own)

        #expect(await ipad.session.refresh() == [.savedPatterns(own)])
    }
}
