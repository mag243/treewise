import Foundation

/// One device's book of synced records for one scope, such as one drive's folders
/// (ADR 0144): the records it made, what holds after merging every device's file, and what
/// it must take over from the others. A change taken over is applied to the device's own
/// store without being recorded again, so devices do not stamp each other's changes back.
public struct SyncBook: Sendable {
    /// The time a device's settings from before syncing are recorded at, before any real
    /// change, so they win only where no device knows the element.
    public static let seedTime = Date(timeIntervalSince1970: 0)

    /// What reading the files brought.
    public struct Absorbed: Sendable, Equatable {
        /// The other devices' records that now hold and were not taken over, to apply.
        public let taken: [SyncRecord]
        /// This device's records that lost to a record not built on them: a real conflict,
        /// for the safety net.
        public let lost: [SyncRecord]
    }

    /// This device's id.
    public let device: String
    /// The records this device made that still hold, one per key.
    public private(set) var own: [SyncKey: SyncRecord] = [:]
    /// What holds for each key, of every device's records.
    public private(set) var merged: [SyncKey: SyncRecord] = [:]
    /// What was taken over last for each key, so it is not taken over again.
    private var taken: [SyncKey: SyncRecord] = [:]

    /// An empty book of `device`.
    public init(device: String) {
        self.device = device
    }

    /// The records that hold for `element`, by part.
    public func parts(of element: SyncElement) -> [String: SyncRecord] {
        Dictionary(
            uniqueKeysWithValues: merged.filter { $0.key.element == element }.map {
                ($0.key.part, $0.value)
            })
    }

    /// Records changes this device made to parts, each stamped after the part's record this
    /// device has seen, so it holds, and naming that record as the one it replaced.
    public mutating func record(_ values: [SyncKey: JSONValue], now: Date) {
        for (key, value) in values {
            let held = merged[key]
            let made = SyncRecord(
                key: key, value: value, changedAt: SyncMerge.stamp(now: now, after: held),
                device: device, replaced: held?.stamp)
            own[key] = made
            merged[key] = made
        }
    }

    /// Records Treewise moving the folder at `old` to `new`, with the folders inside it.
    public mutating func move(folder old: String, to new: String, now: Date) {
        let date = merged.values.reduce(now) { SyncMerge.stamp(now: $0, after: $1) }
        for made in SyncMove.records(
            movingFolder: old, to: new, known: merged, at: date, device: device)
        {
            own[made.key] = made
            merged[made.key] = made
        }
    }

    /// Records the device's settings from before syncing, at `seedTime`, for each element
    /// no device's record names, removals included.
    public mutating func seed(_ values: [SyncKey: JSONValue]) {
        let known = Set(merged.keys.map(\.element))
        for (key, value) in values where !known.contains(key.element) {
            let made = SyncRecord(key: key, value: value, changedAt: Self.seedTime, device: device)
            own[key] = made
            merged[key] = made
        }
    }

    /// Takes in the records read: `others` from the other devices' files and `ownInFile`
    /// from this device's own. Returns the other devices' records to apply, and this
    /// device's records that lost to one not built on them; keeps of its own only those
    /// that hold.
    public mutating func absorb(
        others: [SyncRecord], ownInFile: [SyncRecord], now: Date
    ) -> Absorbed {
        for record in ownInFile
        where own[record.key].map({ SyncMerge.isNewer(record, than: $0) }) ?? true {
            own[record.key] = record
        }
        let before = own
        merged = SyncMerge.merge(Array(own.values) + others, now: now)
        let kept = SyncMerge.pruned(
            own: Array(own.values), merged: merged, others: others, now: now)
        own = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0) })
        let lost = before.values.filter { mine in
            guard let winner = merged[mine.key], winner.device != device else { return false }
            return winner.replaced != mine.stamp && mine.changedAt != Self.seedTime
        }
        var toApply: [SyncRecord] = []
        for (key, winner) in merged where winner.device != device && taken[key] != winner {
            taken[key] = winner
            toApply.append(winner)
        }
        return Absorbed(
            taken: toApply.sorted { $0.key.order < $1.key.order },
            lost: lost.sorted { $0.key.order < $1.key.order })
    }
}
