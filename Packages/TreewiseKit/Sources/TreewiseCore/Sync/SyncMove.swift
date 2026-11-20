import Foundation

/// A folder Treewise moved or renamed in a drive, as records every device follows
/// (ADR 0144).
public enum SyncMove {
    /// The records of moving the folder at `old` to `new`, paths from the drive's root: for
    /// it and each folder inside it with settings in `known`, a removal at the old path and
    /// the settings at the new one, all at `date` by `device`. A folder whose name only
    /// starts as the old one's is not inside it.
    public static func records(
        movingFolder old: String, to new: String, known: [SyncKey: SyncRecord], at date: Date,
        device: String
    ) -> [SyncRecord] {
        let inside = old + "/"
        return known.values.flatMap { record -> [SyncRecord] in
            guard case .folder(let path) = record.key, let value = record.value,
                path == old || path.hasPrefix(inside)
            else { return [] }
            let moved = new + path.dropFirst(old.count)
            return [
                SyncRecord(key: record.key, value: nil, changedAt: date, device: device),
                SyncRecord(key: .folder(moved), value: value, changedAt: date, device: device),
            ]
        }
    }
}
