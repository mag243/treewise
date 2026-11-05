/// Turns approved renames into steps that can run in order (ADR 0057). Names
/// compare as `ConflictResolver` compares them. It is pure: the caller says which
/// names each folder holds.
public enum BatchRenamePlanner {
    /// The start of a temporary name. The dot keeps it out of normal listings if
    /// a batch stops halfway.
    private static let temporaryPrefix = ".treewise-rename-"

    /// Plans a batch: every conflict if there is one, otherwise the steps.
    /// A name that a rename in the batch gives up counts as free.
    public static func plan(
        _ renames: [BatchRename], namesInFolders: [FileItem.ID: [String]]
    ) -> BatchRenamePlan {
        let folders = renames.map(\.folder).uniqued()
        let byFolder = Dictionary(grouping: renames, by: \.folder)
        let conflicts = renames.compactMap { rename in
            conflict(
                for: rename, among: byFolder[rename.folder, default: []],
                names: namesInFolders[rename.folder, default: []])
        }
        guard conflicts.isEmpty else { return .conflicts(conflicts) }
        return .ready(
            folders.flatMap { folder in
                steps(
                    for: byFolder[folder, default: []], names: namesInFolders[folder, default: []])
            })
    }

    private static func conflict(
        for rename: BatchRename, among siblings: [BatchRename], names: [String]
    ) -> BatchRenameConflict? {
        let target = key(rename.to)
        if siblings.count(where: { key($0.to) == target }) > 1 {
            return BatchRenameConflict(item: rename.item, kind: .duplicateInBatch)
        }
        let givenUp = Set(siblings.map { key($0.from) })
        guard names.contains(where: { key($0) == target }), !givenUp.contains(target) else {
            return nil
        }
        return BatchRenameConflict(item: rename.item, kind: .nameTaken(rename.to))
    }

    /// Orders one folder's renames. Each target is wanted once, so the renames
    /// form separate chains and cycles. A chain runs from its free end, and a
    /// cycle opens by moving one item aside.
    private static func steps(for renames: [BatchRename], names: [String]) -> [BatchRenameStep] {
        // A case-sensitive volume can hold two names that compare as one here.
        let bySource = Dictionary(renames.map { (key($0.from), $0) }) { first, _ in first }
        let byTarget = Dictionary(uniqueKeysWithValues: renames.map { (key($0.to), $0) })
        var taken = Set((names + renames.map(\.to)).map(key))
        var result: [BatchRenameStep] = []
        var done = Set<FileItem.ID>()

        /// The rename waiting for this one to give up its name, if any.
        func waiting(for rename: BatchRename) -> BatchRename? {
            byTarget[key(rename.from)].flatMap { $0.item == rename.item ? nil : $0 }
        }

        for start in renames {
            let blocker = bySource[key(start.to)]
            guard blocker == nil || blocker?.item == start.item else { continue }
            var current: BatchRename? = start
            while let rename = current, !done.contains(rename.item) {
                result.append(BatchRenameStep(item: rename.item, from: rename.from, to: rename.to))
                done.insert(rename.item)
                current = waiting(for: rename)
            }
        }
        for start in renames where !done.contains(start.item) {
            let temporary = temporaryName(avoiding: &taken)
            result.append(BatchRenameStep(item: start.item, from: start.from, to: temporary))
            done.insert(start.item)
            var current = waiting(for: start)
            while let rename = current, !done.contains(rename.item) {
                result.append(BatchRenameStep(item: rename.item, from: rename.from, to: rename.to))
                done.insert(rename.item)
                current = waiting(for: rename)
            }
            result.append(BatchRenameStep(item: start.item, from: temporary, to: start.to))
        }
        return result
    }

    private static func temporaryName(avoiding taken: inout Set<String>) -> String {
        var number = 1
        while taken.contains(key(temporaryPrefix + String(number))) { number += 1 }
        let name = temporaryPrefix + String(number)
        taken.insert(key(name))
        return name
    }

    private static func key(_ name: String) -> String {
        ConflictResolver.comparisonKey(name)
    }
}

extension Sequence where Element: Hashable {
    /// The elements without repeats, in their first order.
    fileprivate func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
