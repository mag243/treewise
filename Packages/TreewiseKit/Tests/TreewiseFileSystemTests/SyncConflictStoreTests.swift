import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

@testable import TreewiseFileSystem

/// The safety net kept on this device for 30 days (ADR 0144).
@Suite struct SyncConflictStoreTests {
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)

    private static func entry(daysAgo: Double, part: String = "name") -> SyncConflictStore.Entry {
        let key = SyncKey(.template("t1"), part)
        let at = now.addingTimeInterval(-daysAgo * 86_400)
        return SyncConflictStore.Entry(
            conflict: SyncBook.Conflict(
                mine: SyncRecord(key: key, value: .string("Mine"), changedAt: at, device: "mac"),
                winner: SyncRecord(
                    key: key, value: .string("Theirs"), changedAt: at, device: "ipad")),
            foundAt: at, byDevice: "iPad")
    }

    @Test func keepsWhatWasAddedNewestFirst() async throws {
        let store = SyncConflictStore(directory: try TempDirectory().url)
        await store.add([Self.entry(daysAgo: 2)], now: Self.now)
        await store.add([Self.entry(daysAgo: 1, part: "x")], now: Self.now)
        #expect(await store.entries(now: Self.now).map(\.conflict.mine.key.part) == ["x", "name"])
    }

    @Test func dropsWhatIsOlderThanThirtyDays() async throws {
        let store = SyncConflictStore(directory: try TempDirectory().url)
        await store.add(
            [Self.entry(daysAgo: 31), Self.entry(daysAgo: 29, part: "x")], now: Self.now)
        #expect(await store.entries(now: Self.now).map(\.conflict.mine.key.part) == ["x"])
    }

    @Test func removesOneAndClearsAll() async throws {
        let store = SyncConflictStore(directory: try TempDirectory().url)
        let one = Self.entry(daysAgo: 1)
        await store.add([one, Self.entry(daysAgo: 1, part: "x")], now: Self.now)
        await store.remove(one, now: Self.now)
        #expect(await store.entries(now: Self.now).count == 1)
        await store.clear()
        #expect(await store.entries(now: Self.now).isEmpty)
    }
}
