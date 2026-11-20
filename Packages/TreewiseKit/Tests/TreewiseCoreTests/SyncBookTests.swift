import Foundation
import Testing
import TreewiseCore

/// One device's book of synced records (ADR 0144): what it changed, what holds after
/// merging every device's file, and what it must take over from the others.
@Suite struct SyncBookTests {
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)
    private static let key = SyncKey.folder("Clients")

    private static func settings(_ module: String) -> SyncValue {
        .folder(FolderSettings(enabledModules: [module], templates: [:]))
    }

    private static func record(
        _ module: String?, at date: Date, device: String, key: SyncKey = key
    ) -> SyncRecord {
        SyncRecord(key: key, value: module.map(settings), changedAt: date, device: device)
    }

    @Test func aChangeIsOwnAndHolds() {
        var book = SyncBook(device: "mac")
        let made = book.record(Self.key, Self.settings("a"), now: Self.now)
        #expect(book.own[Self.key] == made)
        #expect(book.merged[Self.key] == made)
        #expect(made.device == "mac" && made.changedAt == Self.now)
    }

    @Test func anotherDevicesNewerChangeIsToBeTakenOver() {
        var book = SyncBook(device: "mac")
        let theirs = Self.record("b", at: Self.now, device: "ipad")
        let taken = book.absorb(others: [theirs], ownInFile: [], now: Self.now)
        #expect(taken == [theirs])
        #expect(book.merged[Self.key] == theirs)
    }

    @Test func whatWasTakenOverIsNotTakenAgain() {
        var book = SyncBook(device: "mac")
        let theirs = Self.record("b", at: Self.now, device: "ipad")
        _ = book.absorb(others: [theirs], ownInFile: [], now: Self.now)
        #expect(book.absorb(others: [theirs], ownInFile: [], now: Self.now).isEmpty)
    }

    @Test func takingOverMakesNoRecordOfItsOwn() {
        var book = SyncBook(device: "mac")
        _ = book.absorb(
            others: [Self.record("b", at: Self.now, device: "ipad")], ownInFile: [], now: Self.now)
        #expect(book.own.isEmpty, "a change from another device is not stamped again")
    }

    @Test func anOwnChangeThatHoldsIsNotTakenOver() {
        var book = SyncBook(device: "mac")
        let older = Self.record("b", at: Self.now.addingTimeInterval(-60), device: "ipad")
        _ = book.record(Self.key, Self.settings("a"), now: Self.now)
        #expect(book.absorb(others: [older], ownInFile: [], now: Self.now).isEmpty)
    }

    @Test func anOwnChangeLostToANewerOneIsDroppedFromItsOwn() {
        var book = SyncBook(device: "mac")
        _ = book.record(Self.key, Self.settings("a"), now: Self.now)
        let newer = Self.record("b", at: Self.now.addingTimeInterval(60), device: "ipad")
        let taken = book.absorb(others: [newer], ownInFile: [], now: Self.now)
        #expect(taken == [newer])
        #expect(book.own.isEmpty)
    }

    @Test func aChangeAfterSeeingANewerOneWinsWhateverTheClock() {
        var book = SyncBook(device: "mac")
        let ahead = Self.record("b", at: Self.now.addingTimeInterval(3600), device: "ipad")
        _ = book.absorb(others: [ahead], ownInFile: [], now: Self.now)
        let made = book.record(Self.key, Self.settings("a"), now: Self.now)
        #expect(SyncMerge.isNewer(made, than: ahead))
    }

    @Test func itsOwnFileIsReadBackAfterAStart() {
        let earlier = Self.record("a", at: Self.now, device: "mac")
        var book = SyncBook(device: "mac")
        let taken = book.absorb(others: [], ownInFile: [earlier], now: Self.now)
        #expect(taken.isEmpty)
        #expect(book.own[Self.key] == earlier)
    }

    @Test func seedingRecordsOnlyWhatNoFileKnows() {
        var book = SyncBook(device: "mac")
        let removedElsewhere = Self.record(nil, at: Self.now, device: "ipad")
        _ = book.absorb(others: [removedElsewhere], ownInFile: [], now: Self.now)
        let other = SyncKey.folder("Photos")
        book.seed([Self.key: Self.settings("a"), other: Self.settings("p")])
        #expect(book.own[Self.key] == nil, "a key a file knows, removals too, is not seeded")
        #expect(book.own[other]?.changedAt == SyncBook.seedTime)
    }

    @Test func aSeedLosesToAnyRealChange() {
        var book = SyncBook(device: "zz-late")
        book.seed([Self.key: Self.settings("old")])
        let real = Self.record("new", at: Self.now.addingTimeInterval(-86_400 * 365), device: "a")
        let taken = book.absorb(others: [real], ownInFile: [], now: Self.now)
        #expect(taken == [real])
    }

    @Test func aMoveRecordsTheOldPathRemovedAndTheNewOne() {
        var book = SyncBook(device: "mac")
        _ = book.absorb(
            others: [Self.record("b", at: Self.now, device: "ipad")], ownInFile: [],
            now: Self.now)
        book.move(folder: "Clients", to: "Archive/Clients", now: Self.now)
        #expect(book.merged[Self.key]?.isRemoval == true)
        #expect(book.merged[.folder("Archive/Clients")]?.value == Self.settings("b"))
        #expect(book.own.count == 2)
    }
}
