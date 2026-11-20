import Foundation

/// Merges the records of every device's file into one view (ADR 0144).
public enum SyncMerge {
    /// How long a removal is kept, so the thing removed does not come back from a device
    /// that was away: 90 days.
    public static let removalKept: TimeInterval = 90 * 24 * 60 * 60

    /// The record that holds for each key: the newest, and on the same time the one of the
    /// higher device id, so every device chooses the same. A removal older than
    /// `removalKept` before `now` is dropped; a value is kept however old.
    public static func merge(_ records: [SyncRecord], now: Date) -> [SyncKey: SyncRecord] {
        var winners: [SyncKey: SyncRecord] = [:]
        for record in records {
            if let held = winners[record.key], !isNewer(record, than: held) { continue }
            winners[record.key] = record
        }
        return winners.filter { _, record in
            !record.isRemoval || now.timeIntervalSince(record.changedAt) <= removalKept
        }
    }

    /// Whether `record` wins over `held`.
    public static func isNewer(_ record: SyncRecord, than held: SyncRecord) -> Bool {
        record.changedAt != held.changedAt
            ? record.changedAt > held.changedAt : record.device > held.device
    }
}
