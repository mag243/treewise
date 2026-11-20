import Foundation
import Testing
import TreewiseCore

/// One device's book of synced records (ADR 0144): what it changed, what holds after
/// merging every device's file, what it takes over, and what it lost in a real conflict.
@Suite struct SyncBookTests {
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)
    private static let element = SyncElement.folder("Clients")
    private static let key = SyncKey(element, "enabledModules")

    private static func record(
        _ module: String, at date: Date, device: String, replaced: SyncStamp? = nil
    ) -> SyncRecord {
        SyncRecord(
            key: key, value: .string(module), changedAt: date, device: device, replaced: replaced)
    }

    private static func absorb(_ book: inout SyncBook, _ others: [SyncRecord]) -> SyncBook.Absorbed
    {
        book.absorb(others: others, ownInFile: [], now: now)
    }

    @Test func aChangeIsOwnAndHolds() {
        var book = SyncBook(device: "mac")
        book.record([Self.key: .string("a")], now: Self.now)
        let made = book.own[Self.key]
        #expect(made?.device == "mac" && made?.changedAt == Self.now)
        #expect(book.merged[Self.key] == made)
    }

    @Test func aChangeNamesTheRecordItReplaced() {
        var book = SyncBook(device: "mac")
        let theirs = Self.record("b", at: Self.now.addingTimeInterval(-60), device: "ipad")
        _ = Self.absorb(&book, [theirs])
        book.record([Self.key: .string("a")], now: Self.now)
        #expect(book.own[Self.key]?.replaced == theirs.stamp)
    }

    @Test func anotherDevicesNewerChangeIsToBeTakenOverOnce() {
        var book = SyncBook(device: "mac")
        let theirs = Self.record("b", at: Self.now, device: "ipad")
        #expect(Self.absorb(&book, [theirs]).taken == [theirs])
        #expect(Self.absorb(&book, [theirs]).taken.isEmpty)
        #expect(book.own.isEmpty, "a change from another device is not stamped again")
    }

    @Test func aChangeAfterSeeingANewerOneWinsWhateverTheClock() {
        var book = SyncBook(device: "mac")
        let ahead = Self.record("b", at: Self.now.addingTimeInterval(3600), device: "ipad")
        _ = Self.absorb(&book, [ahead])
        book.record([Self.key: .string("a")], now: Self.now)
        #expect(book.own[Self.key].map { SyncMerge.isNewer($0, than: ahead) } == true)
    }

    @Test func itsOwnFileIsReadBackAfterAStart() {
        let earlier = Self.record("a", at: Self.now, device: "mac")
        var book = SyncBook(device: "mac")
        let absorbed = book.absorb(others: [], ownInFile: [earlier], now: Self.now)
        #expect(absorbed.taken.isEmpty)
        #expect(book.own[Self.key] == earlier)
    }

    @Test func seedingRecordsOnlyElementsNoFileKnows() {
        var book = SyncBook(device: "mac")
        let removedElsewhere = SyncRecord(
            key: .exists(Self.element), value: .bool(false), changedAt: Self.now, device: "ipad")
        _ = Self.absorb(&book, [removedElsewhere])
        let other = SyncKey(.folder("Photos"), "enabledModules")
        book.seed([Self.key: .string("a"), other: .string("p")])
        #expect(book.own[Self.key] == nil, "an element a file knows, removed too, is not seeded")
        #expect(book.own[other]?.changedAt == SyncBook.seedTime)
    }

    @Test func aSeedLosesToAnyRealChangeAndIsNotMissed() {
        var book = SyncBook(device: "zz-late")
        book.seed([Self.key: .string("old")])
        let real = Self.record("new", at: Self.now.addingTimeInterval(-86_400 * 365), device: "a")
        let absorbed = Self.absorb(&book, [real])
        #expect(absorbed.taken == [real])
        #expect(absorbed.lost.isEmpty)
    }

    // MARK: - The safety net

    @Test func aChangeBuiltOnMineLosesNothing() {
        var book = SyncBook(device: "mac")
        book.record([Self.key: .string("a")], now: Self.now)
        let mine = book.own[Self.key]?.stamp
        let after = Self.record(
            "b", at: Self.now.addingTimeInterval(60), device: "ipad", replaced: mine)
        #expect(Self.absorb(&book, [after]).lost.isEmpty)
    }

    @Test func aChangeThatDidNotSeeMineIsAConflict() {
        var book = SyncBook(device: "mac")
        book.record([Self.key: .string("a")], now: Self.now)
        let mine = book.own[Self.key]
        let blind = Self.record("b", at: Self.now.addingTimeInterval(60), device: "ipad")
        #expect(Self.absorb(&book, [blind]).lost == [mine].compactMap { $0 })
    }

    @Test func theWinnerOfAConflictLosesNothing() {
        var book = SyncBook(device: "mac")
        book.record([Self.key: .string("a")], now: Self.now.addingTimeInterval(60))
        let older = Self.record("b", at: Self.now, device: "ipad")
        #expect(Self.absorb(&book, [older]).lost.isEmpty)
    }

    @Test func aMoveRecordsTheOldPathRemovedAndTheNewOne() {
        var book = SyncBook(device: "mac")
        _ = Self.absorb(
            &book,
            [
                SyncRecord(
                    key: .exists(Self.element), value: .bool(true), changedAt: Self.now,
                    device: "ipad"),
                Self.record("b", at: Self.now, device: "ipad"),
            ])
        book.move(folder: "Clients", to: "Archive/Clients", now: Self.now)
        #expect(book.merged[.exists(Self.element)]?.isRemoval == true)
        #expect(
            book.merged[SyncKey(.folder("Archive/Clients"), "enabledModules")]?.value
                == .string("b"))
    }
}
