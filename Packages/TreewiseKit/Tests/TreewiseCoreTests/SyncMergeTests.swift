import Foundation
import Testing
import TreewiseCore

/// How the records of several devices merge into one view (ADR 0144).
@Suite struct SyncMergeTests {
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)
    private static let key = SyncKey.folder("Clients/2026")
    private static let day: TimeInterval = 24 * 60 * 60

    private static func record(
        _ pattern: String?, minutesAgo: Double, device: String, key: SyncKey = key
    ) -> SyncRecord {
        SyncRecord(
            key: key,
            value: pattern.map { .folder(FolderSettings(enabledModules: [$0], templates: [:])) },
            changedAt: now.addingTimeInterval(-minutesAgo * 60), device: device)
    }

    private static func merged(_ records: [SyncRecord]) -> SyncRecord? {
        SyncMerge.merge(records, now: now)[key]
    }

    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let records: [SyncRecord]
        /// The enabled module of the winner, "removed" for a removal, nil for none.
        let winner: String?
        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(
            name: "the newest wins over an older one from another device",
            records: [
                record("a", minutesAgo: 5, device: "mac"),
                record("b", minutesAgo: 1, device: "ipad"),
            ], winner: "b"),
        Case(
            name: "the newest wins whatever the order",
            records: [
                record("b", minutesAgo: 1, device: "ipad"),
                record("a", minutesAgo: 5, device: "mac"),
            ], winner: "b"),
        Case(
            name: "on the same time the higher device id wins",
            records: [
                record("a", minutesAgo: 2, device: "b-device"),
                record("b", minutesAgo: 2, device: "a-device"),
            ], winner: "a"),
        Case(
            name: "a newer removal wins over a value",
            records: [
                record("a", minutesAgo: 5, device: "mac"),
                record(nil, minutesAgo: 1, device: "ipad"),
            ], winner: "removed"),
        Case(
            name: "a newer value wins over an older removal",
            records: [
                record(nil, minutesAgo: 5, device: "mac"),
                record("b", minutesAgo: 1, device: "ipad"),
            ], winner: "b"),
        Case(name: "nothing recorded gives nothing", records: [], winner: nil),
    ]

    @Test(arguments: cases) func mergesToTheNewest(_ test: Case) {
        let winner = Self.merged(test.records)
        switch winner?.value {
        case nil: #expect((winner == nil ? nil : "removed") == test.winner)
        case .folder(let settings): #expect(settings.enabledModules.first == test.winner)
        default: Issue.record("an unexpected kind of value")
        }
    }

    @Test func anOldRemovalStillWinsInTheMerge() {
        let old = Self.record(
            nil, minutesAgo: (SyncMerge.removalKept + Self.day) / 60, device: "mac")
        let older = Self.record(
            "a", minutesAgo: (SyncMerge.removalKept + 2 * Self.day) / 60, device: "ipad")
        #expect(Self.merged([old, older]) == old, "a device back after months keeps it removed")
    }

    // MARK: - A device's own file, pruned

    private static func pruned(own: [SyncRecord], others: [SyncRecord]) -> [SyncRecord] {
        let merged = SyncMerge.merge(own + others, now: now)
        return SyncMerge.pruned(own: own, merged: merged, others: others, now: now)
    }

    @Test func anOwnRemovalPastItsKeepingIsDroppedWhenNoOtherFileHoldsTheValue() {
        let old = Self.record(
            nil, minutesAgo: (SyncMerge.removalKept + Self.day) / 60, device: "mac")
        #expect(Self.pruned(own: [old], others: []).isEmpty)
    }

    @Test func anOwnRemovalStaysWhileAnotherFileStillHoldsTheValue() {
        let old = Self.record(
            nil, minutesAgo: (SyncMerge.removalKept + Self.day) / 60, device: "mac")
        let leftBehind = Self.record(
            "a", minutesAgo: (SyncMerge.removalKept + 2 * Self.day) / 60, device: "gone")
        #expect(
            Self.pruned(own: [old], others: [leftBehind]) == [old],
            "an uninstalled device's file never brings it back")
    }

    @Test func anOwnRemovalWithinItsKeepingStays() {
        let recent = Self.record(
            nil, minutesAgo: (SyncMerge.removalKept - Self.day) / 60, device: "mac")
        #expect(Self.pruned(own: [recent], others: []) == [recent])
    }

    @Test func anOwnValueThatLostIsDropped() {
        let mine = Self.record("a", minutesAgo: 5, device: "mac")
        let newer = Self.record("b", minutesAgo: 1, device: "ipad")
        #expect(Self.pruned(own: [mine], others: [newer]).isEmpty)
    }

    @Test func anOwnValueIsKeptHoweverOld() {
        let old = Self.record("a", minutesAgo: 10 * SyncMerge.removalKept / 60, device: "mac")
        #expect(Self.pruned(own: [old], others: []) == [old])
    }

    // MARK: - The time of a change

    @Test func aChangeIsStampedNowWhenNothingNewerIsKnown() {
        let held = Self.record("a", minutesAgo: 5, device: "ipad")
        #expect(SyncMerge.stamp(now: Self.now, after: held) == Self.now)
    }

    @Test func aChangeIsStampedAfterWhatTheDeviceAlreadySaw() {
        let ahead = SyncRecord(
            key: Self.key, value: nil, changedAt: Self.now.addingTimeInterval(3600),
            device: "ipad")
        let stamp = SyncMerge.stamp(now: Self.now, after: ahead)
        #expect(stamp > ahead.changedAt, "an edit beats what was seen, whatever the clock says")
    }

    @Test func eachKeyMergesOnItsOwn() {
        let other = SyncKey.template("t1")
        let records = [
            Self.record("a", minutesAgo: 1, device: "mac"),
            Self.record(nil, minutesAgo: 1, device: "mac", key: other),
        ]
        let result = SyncMerge.merge(records, now: Self.now)
        #expect(result.count == 2)
        #expect(result[other]?.value == nil)
    }
}
