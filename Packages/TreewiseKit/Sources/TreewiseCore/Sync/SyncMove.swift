import Foundation

/// A folder Treewise moved or renamed in a drive, as records every device follows
/// (ADR 0144).
public enum SyncMove {
    /// The records of moving the folder at `old` to `new`, paths from the drive's root: for
    /// it and each folder inside it with settings in `known`, its removal at the old path and
    /// each of its parts at the new one, all at `date` by `device`. A folder whose name only
    /// starts as the old one's is not inside it.
    public static func records(
        movingFolder old: String, to new: String, known: [SyncKey: SyncRecord], at date: Date,
        device: String
    ) -> [SyncRecord] {
        let inside = old + "/"
        var byFolder: [String: [SyncRecord]] = [:]
        for record in known.values where record.value != .null {
            guard case .folder(let path) = record.key.element, path == old || path.hasPrefix(inside)
            else { continue }
            byFolder[path, default: []].append(record)
        }
        return byFolder.flatMap { path, records -> [SyncRecord] in
            guard !records.contains(where: \.isRemoval) else { return [] }
            let moved = SyncElement.folder(new + path.dropFirst(old.count))
            let gone = SyncRecord(
                key: .exists(.folder(path)), value: .bool(false), changedAt: date, device: device,
                replaced: known[.exists(.folder(path))]?.stamp)
            return [gone]
                + records.map {
                    SyncRecord(
                        key: SyncKey(moved, $0.key.part), value: $0.value, changedAt: date,
                        device: device, replaced: known[SyncKey(moved, $0.key.part)]?.stamp)
                }
        }
    }
}
