import Foundation

/// What a change records part by part, and what an element is from its records (ADR 0144).
public enum SyncParts {
    /// The parts to record for `element` going from `before` to `after`, nil for an element
    /// that is not there: only the parts that differ, a part that is gone as `null`; a new
    /// element also says it exists, a removed one only that it does not.
    public static func changes(
        of element: SyncElement, from before: [String: JSONValue]?, to after: [String: JSONValue]?
    ) -> [SyncKey: JSONValue] {
        guard let after else {
            return before == nil ? [:] : [.exists(element): .bool(false)]
        }
        var changes: [SyncKey: JSONValue] = [:]
        if before == nil { changes[.exists(element)] = .bool(true) }
        let old = before ?? [:]
        for (part, value) in after where old[part] != value {
            changes[SyncKey(element, part)] = value
        }
        for part in old.keys where after[part] == nil {
            changes[SyncKey(element, part)] = .null
        }
        return changes
    }

    /// The changes over several elements, as `changes(of:from:to:)` for each.
    public static func changes(
        from before: [SyncElement: [String: JSONValue]],
        to after: [SyncElement: [String: JSONValue]]
    ) -> [SyncKey: JSONValue] {
        var all: [SyncKey: JSONValue] = [:]
        for element in Set(before.keys).union(after.keys) {
            all.merge(changes(of: element, from: before[element], to: after[element])) { $1 }
        }
        return all
    }

    /// The parts of an element from the records that hold for it, without `exists` and
    /// without parts that are gone; nil when it is not there: no records, or removed and no
    /// part changed after the removal, which would bring it back.
    public static func values(of records: [String: SyncRecord]) -> [String: JSONValue]? {
        guard !records.isEmpty else { return nil }
        if let exists = records[SyncKey.exists], exists.isRemoval {
            let changedSince = records.values.contains {
                $0.key.part != SyncKey.exists && $0.changedAt > exists.changedAt
            }
            guard changedSince else { return nil }
        }
        return lastParts(of: records)
    }

    /// The parts of an element from its records, whether it is there or not.
    public static func lastParts(of records: [String: SyncRecord]) -> [String: JSONValue] {
        records.filter { $0.key != SyncKey.exists && $0.value.value != .null }
            .mapValues(\.value)
    }
}
