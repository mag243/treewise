import Foundation
import Testing
import TreewiseCore

/// What a change records, part by part, and when an element is there (ADR 0144).
@Suite struct SyncPartsTests {
    private static let element = SyncElement.folder("Clients")
    private static let at = Date(timeIntervalSince1970: 2_000_000_000)

    @Test func onlyTheChangedPartsAreRecorded() {
        let changes = SyncParts.changes(
            of: Self.element, from: ["a": .string("1"), "b": .string("2")],
            to: ["a": .string("1"), "b": .string("3")])
        #expect(changes == [SyncKey(Self.element, "b"): .string("3")])
    }

    @Test func aPartThatIsGoneIsRecordedAsNull() {
        let changes = SyncParts.changes(
            of: Self.element, from: ["a": .string("1")], to: [:])
        #expect(changes == [SyncKey(Self.element, "a"): .null])
    }

    @Test func aNewElementRecordsThatItExistsAndItsParts() {
        let changes = SyncParts.changes(of: Self.element, from: nil, to: ["a": .string("1")])
        #expect(
            changes == [
                .exists(Self.element): .bool(true), SyncKey(Self.element, "a"): .string("1"),
            ])
    }

    @Test func aRemovedElementRecordsOnlyThatItIsGone() {
        let changes = SyncParts.changes(of: Self.element, from: ["a": .string("1")], to: nil)
        #expect(changes == [.exists(Self.element): .bool(false)])
    }

    @Test func nothingChangedRecordsNothing() {
        #expect(
            SyncParts.changes(of: Self.element, from: ["a": .bool(true)], to: ["a": .bool(true)])
                .isEmpty)
    }

    private static func record(_ part: String, _ value: JSONValue, minutes: Double) -> SyncRecord {
        SyncRecord(
            key: SyncKey(element, part), value: value,
            changedAt: at.addingTimeInterval(minutes * 60), device: "mac")
    }

    @Test func anElementIsItsPartsWithoutNulls() {
        let parts = [
            "exists": Self.record("exists", .bool(true), minutes: 0),
            "a": Self.record("a", .string("1"), minutes: 0),
            "b": Self.record("b", .null, minutes: 1),
        ]
        #expect(SyncParts.values(of: parts) == ["a": .string("1")])
    }

    @Test func aRemovedElementIsNotThere() {
        let parts = [
            "exists": Self.record("exists", .bool(false), minutes: 2),
            "a": Self.record("a", .string("1"), minutes: 1),
        ]
        #expect(SyncParts.values(of: parts) == nil)
    }

    @Test func aChangeAfterTheRemovalBringsTheElementBack() {
        let parts = [
            "exists": Self.record("exists", .bool(false), minutes: 1),
            "a": Self.record("a", .string("2"), minutes: 2),
        ]
        #expect(SyncParts.values(of: parts) == ["a": .string("2")])
    }

    @Test func noRecordsIsNoElement() {
        #expect(SyncParts.values(of: [:]) == nil)
    }
}
