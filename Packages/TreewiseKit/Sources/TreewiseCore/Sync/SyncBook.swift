import Foundation

/// One device's book of synced records for one scope, such as one drive's folders
/// (ADR 0144): the records it made, what holds after merging every device's file, and what
/// it must take over from the others. A change taken over is applied to the device's own
/// store without being recorded again, so devices do not stamp each other's changes back.
public struct SyncBook: Sendable {
    /// The time a device's settings from before syncing are recorded at, before any real
    /// change, so they win only where no device knows the key.
    public static let seedTime = Date(timeIntervalSince1970: 0)

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

    /// Records a change this device made: `value`, or nil for a removal the user made.
    /// It is stamped after the key's record this device has seen, so it holds.
    @discardableResult
    public mutating func record(_ key: SyncKey, _ value: SyncValue?, now: Date) -> SyncRecord {
        let made = SyncRecord(
            key: key, value: value, changedAt: SyncMerge.stamp(now: now, after: merged[key]),
            device: device)
        own[key] = made
        merged[key] = made
        return made
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

    /// Records the device's settings from before syncing, at `seedTime`, for each key no
    /// device's record names, removals included.
    public mutating func seed(_ values: [SyncKey: SyncValue]) {
        for (key, value) in values where merged[key] == nil {
            let made = SyncRecord(key: key, value: value, changedAt: Self.seedTime, device: device)
            own[key] = made
            merged[key] = made
        }
    }

    /// Takes in the records read: `others` from the other devices' files and `ownInFile`
    /// from this device's own. Returns the other devices' records that hold and that the
    /// device has not taken over, for it to apply to its store; drops this device's records
    /// that a newer one beats.
    public mutating func absorb(
        others: [SyncRecord], ownInFile: [SyncRecord], now: Date
    ) -> [SyncRecord] {
        for record in ownInFile
        where own[record.key].map({ SyncMerge.isNewer(record, than: $0) }) ?? true {
            own[record.key] = record
        }
        merged = SyncMerge.merge(Array(own.values) + others, now: now)
        let kept = SyncMerge.pruned(
            own: Array(own.values), merged: merged, others: others, now: now)
        own = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0) })
        var toApply: [SyncRecord] = []
        for (key, winner) in merged where winner.device != device && taken[key] != winner {
            taken[key] = winner
            toApply.append(winner)
        }
        return toApply.sorted { $0.key.text < $1.key.text }
    }
}
