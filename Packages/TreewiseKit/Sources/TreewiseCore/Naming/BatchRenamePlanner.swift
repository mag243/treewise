/// Turns approved renames into steps that can run in order (ADR 0057). Names
/// compare as `ConflictResolver` compares them. It is pure: the caller says which
/// names each folder holds.
///
/// The plan assumes a default APFS volume. On a case-sensitive volume two names can
/// compare as one, and then a planned step can fail when it runs, which the caller
/// has to report like any other failed rename.
public enum BatchRenamePlanner {
    /// The start of a temporary name. The dot keeps it out of normal listings if
    /// a batch stops halfway.
    static let temporaryPrefix = ".treewise-rename-"

    /// Plans a batch: every conflict if there is one, otherwise the steps.
    /// A name that a rename in the batch gives up counts as free.
    public static func plan(
        _ renames: [BatchRename], namesInFolders: [FileItem.ID: [String]]
    ) -> BatchRenamePlan {
        let folders = renames.map(\.folder).uniqued()
        let byFolder = Dictionary(grouping: renames, by: \.folder)
        // Each folder's names are keyed once, not once for every rename in it.
        let keys = byFolder.mapValues { siblings in
            FolderKeys(siblings, names: namesInFolders[siblings[0].folder, default: []])
        }
        let conflicts = renames.compactMap { rename in
            keys[rename.folder].flatMap { conflict(for: rename, in: $0) }
        }
        guard conflicts.isEmpty else { return .conflicts(conflicts) }
        return .ready(
            folders.flatMap { folder in
                steps(
                    for: byFolder[folder, default: []], names: namesInFolders[folder, default: []])
            })
    }

    /// A folder's names and its renames' names, as keys.
    private struct FolderKeys {
        /// How many renames want each name.
        let targets: [String: Int]
        /// The names the renames give up.
        let givenUp: Set<String>
        /// The names in the folder.
        let names: Set<String>

        init(_ renames: [BatchRename], names: [String]) {
            targets = renames.reduce(into: [:]) { counts, rename in
                counts[BatchRenamePlanner.key(rename.to), default: 0] += 1
            }
            givenUp = Set(renames.map { BatchRenamePlanner.key($0.from) })
            self.names = Set(names.map(BatchRenamePlanner.key))
        }
    }

    private static func conflict(for rename: BatchRename, in folder: FolderKeys)
        -> BatchRenameConflict?
    {
        let target = key(rename.to)
        if folder.targets[target, default: 0] > 1 {
            return BatchRenameConflict(item: rename.item, kind: .duplicateInBatch)
        }
        guard folder.names.contains(target), !folder.givenUp.contains(target) else {
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

    fileprivate static func key(_ name: String) -> String {
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
