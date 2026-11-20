import Foundation

/// Merges the records of every device's file into one view, and keeps a device's own file
/// small (ADR 0144).
public enum SyncMerge {
    /// How long a device keeps a removal in its own file: 90 days, and longer while another
    /// file still holds a value for the key.
    public static let removalKept: TimeInterval = 90 * 24 * 60 * 60
    /// How much later than the newest record seen a change is stamped, when the device's
    /// clock is behind.
    public static let step: TimeInterval = 0.001

    /// The record that holds for each key: the newest, and on the same time the one of the
    /// higher device id, so every device chooses the same. A removal wins as any record does,
    /// however old, so nothing removed comes back from a file that still holds it.
    public static func merge(_ records: [SyncRecord], now: Date) -> [SyncKey: SyncRecord] {
        var winners: [SyncKey: SyncRecord] = [:]
        for record in records {
            if let held = winners[record.key], !isNewer(record, than: held) { continue }
            winners[record.key] = record
        }
        return winners
    }

    /// Whether `record` wins over `held`.
    public static func isNewer(_ record: SyncRecord, than held: SyncRecord) -> Bool {
        record.changedAt != held.changedAt
            ? record.changedAt > held.changedAt : record.device > held.device
    }

    /// The records a device keeps in its own file: those of `own` that hold in `merged`,
    /// less a removal older than `removalKept` that no other device's record in `others`
    /// still holds a value against.
    public static func pruned(
        own: [SyncRecord], merged: [SyncKey: SyncRecord], others: [SyncRecord], now: Date
    ) -> [SyncRecord] {
        let valuesElsewhere = Set(others.filter { !$0.isRemoval }.map(\.key))
        return own.filter { record in
            guard merged[record.key] == record else { return false }
            guard record.isRemoval, now.timeIntervalSince(record.changedAt) > removalKept
            else { return true }
            return valuesElsewhere.contains(record.key)
        }
    }

    /// The time to stamp a change at: `now`, or just after `held`, the record of the key the
    /// device has seen, when that is newer, so the change wins whatever the clock says.
    public static func stamp(now: Date, after held: SyncRecord?) -> Date {
        guard let held, held.changedAt >= now else { return now }
        return held.changedAt.addingTimeInterval(step)
    }
}
