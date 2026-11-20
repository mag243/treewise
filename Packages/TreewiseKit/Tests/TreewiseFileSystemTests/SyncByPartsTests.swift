import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

@testable import TreewiseFileSystem

/// Two devices changing parts of the same thing (ADR 0144): different parts both hold, the
/// same part keeps the newer and the loser's in its safety net.
@Suite struct SyncByPartsTests {
    @Test func aDeviceThatHadNotReadTheOthersChangeRecordsOnlyItsOwnPart() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.refresh()

        mac.clock.advance()
        var macChange = SyncTestPair.settings("dates")
        macChange.templateBarClosed = true
        await mac.folders.save(macChange, forFolderAt: folder)
        mac.clock.advance()
        var ipadChange = SyncTestPair.settings("dates")
        ipadChange.alwaysSkipped = ["scan.pdf"]
        await ipad.folders.save(ipadChange, forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.settle()
        await mac.session.refresh()
        await ipad.session.refresh()

        var both = SyncTestPair.settings("dates")
        both.templateBarClosed = true
        both.alwaysSkipped = ["scan.pdf"]
        #expect(await mac.folders.settings(forFolderAt: folder) == both)
        #expect(await ipad.folders.settings(forFolderAt: folder) == both)
        let lost = await mac.session.conflicts + ipad.session.conflicts
        #expect(lost.isEmpty, "no part clashed")
    }

    @Test func theSamePartChangedOnBothIsKeptForTheLoserOnly() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.refresh()

        mac.clock.advance()
        await mac.folders.save(SyncTestPair.settings("older"), forFolderAt: folder)
        mac.clock.advance()
        await ipad.folders.save(SyncTestPair.settings("newer"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.settle()
        await mac.session.refresh()
        await ipad.session.refresh()

        #expect(await mac.folders.settings(forFolderAt: folder) == SyncTestPair.settings("newer"))
        let macLost = await mac.session.conflicts
        let ipadLost = await ipad.session.conflicts
        #expect(macLost.map(\.mine.key.part) == ["enabledModules"])
        #expect(ipadLost.isEmpty)
    }

    @Test func aFolderAddedToATemplateOnOneAndARenameOnTheOtherBothHold() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let template = FolderTemplate(
            id: "t1", name: "Year",
            root: FolderTree(name: "{year}", folders: [FolderTree(name: "Tax")]))
        try await mac.templates.save(template)
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        let shared = try #require(await ipad.templates.templates().first)

        mac.clock.advance()
        let macCopy = try #require(await mac.templates.templates().first)
        try await mac.templates.save(
            FolderTemplate(
                id: "t1", name: "Year", root: try macCopy.root.renaming(["Tax"], to: "Taxes").tree))
        mac.clock.advance()
        try await ipad.templates.save(
            FolderTemplate(
                id: "t1", name: "Year", root: try shared.root.adding(in: [], named: "Receipts").tree
            ))
        await mac.session.settle()
        await ipad.session.settle()
        await mac.session.refresh()
        await ipad.session.refresh()

        for device in [mac, ipad] {
            let names = await device.templates.templates().first?.root.folders.map(\.name)
            #expect(names == ["Receipts", "Taxes"])
        }
    }

    @Test func restoreMakesTheLosersValueHoldOnBoth() async throws {
        let pair = try SyncTestPair.make()
        let (mac, ipad, drive) = (pair.mac, pair.ipad, pair.drive)
        let folder = try drive.makeFolder("Clients").path
        _ = await mac.session.start(drives: [drive.url], patterns: nil)
        _ = await ipad.session.start(drives: [drive.url], patterns: nil)
        await mac.folders.save(SyncTestPair.settings("dates"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.refresh()
        mac.clock.advance()
        await mac.folders.save(SyncTestPair.settings("mine"), forFolderAt: folder)
        mac.clock.advance()
        await ipad.folders.save(SyncTestPair.settings("theirs"), forFolderAt: folder)
        await mac.session.settle()
        await ipad.session.settle()
        await mac.session.refresh()
        let conflict = try #require(await mac.session.conflicts.first)
        #expect(await mac.session.deviceName(conflict.winner.device) == "b-ipad")

        mac.clock.advance()
        _ = await mac.session.restore(conflict)
        await ipad.session.refresh()

        #expect(await mac.folders.settings(forFolderAt: folder) == SyncTestPair.settings("mine"))
        #expect(await ipad.folders.settings(forFolderAt: folder) == SyncTestPair.settings("mine"))
        let ipadConflicts = await ipad.session.conflicts
        #expect(ipadConflicts.isEmpty, "Restore built on the iPad's change")
    }
}
