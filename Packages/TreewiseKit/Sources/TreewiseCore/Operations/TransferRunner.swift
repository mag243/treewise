/// Moves or copies items into a folder one by one, settling name conflicts
/// with a resolver (PLAN.md §4.2, ADR 0018).
///
/// A copy into the item's own folder keeps both without asking. Cancelling or
/// Stop ends the run after the item in progress; what was done stays done and
/// is in the result's undo record.
struct TransferRunner {
    let operations: any FileOperating
    let resolver: any ConflictResolving
    let progress: @Sendable (OperationProgress) -> Void
    /// Pauses and stops the run, inside a file too (ADR 0026).
    let control: TransferControl

    func run(_ items: [FileItem], to folder: FileItem.ID, mode: TransferMode) async throws
        -> OperationResult
    {
        var present = try await keyed(operations.itemsByName(in: folder).values)
        let sizes = try await bytesToCopy(items, to: folder, mode: mode)
        let total = sizes.reduce(0, +)
        var done: Int64 = 0
        var produced: [FileItem] = []
        var undo: [UndoRecord] = []
        // Reported before the first item, so a single long copy shows its progress while it runs.
        progress(OperationProgress(completedBytes: 0, totalBytes: total))
        for (item, size) in zip(items, sizes) {
            guard !Task.isCancelled, await control.untilResumed() else {
                return result(produced, undo, stopped: true)
            }
            guard let origin = item.parentID, !(mode == .move && origin == folder) else { continue }
            var name = item.name
            if let clash = present[ConflictResolver.comparisonKey(name)] {
                switch await decide(clash, item, copyingInPlace: mode == .copy && origin == folder)
                {
                case .stop:
                    return result(produced, undo, stopped: true)
                case .keepBoth:
                    name = ConflictResolver.availableName(
                        for: item.name, kind: item.kind, among: present.values.map(\.name))
                case .replace:
                    undo.append(.restore([try await operations.trash(clash.id)]))
                    present[ConflictResolver.comparisonKey(name)] = nil
                }
            }
            let landed: FileItem
            do {
                landed = try await land(
                    item, in: folder, as: name, mode: mode, bytes: (done, total))
            } catch FileSystemError.cancelled {
                return result(produced, undo, stopped: true)
            }
            present[ConflictResolver.comparisonKey(landed.name)] = landed
            produced.append(landed)
            undo.append(undoRecord(of: item, landedAs: landed, from: origin, mode: mode))
            done += size
            progress(OperationProgress(completedBytes: done, totalBytes: total))
        }
        return result(produced, undo, stopped: false)
    }

    /// Moves or copies one item, reporting each of its files on top of the
    /// bytes done before it.
    private func land(
        _ item: FileItem, in folder: FileItem.ID, as name: String, mode: TransferMode,
        bytes: (done: Int64, total: Int64)
    ) async throws -> FileItem {
        let (done, total) = bytes
        let progress = progress
        let onFile: FileCopyProgress = { file, copied in
            progress(
                OperationProgress(
                    completedBytes: done + copied, totalBytes: total, currentName: file))
        }
        return mode == .move
            ? try await operations.move(
                item, into: folder, as: name, onFile: onFile, control: control)
            : try await operations.copy(
                item, into: folder, as: name, onFile: onFile, control: control)
    }

    /// What undoes landing one item: moving it back, or trashing the copy.
    private func undoRecord(
        of item: FileItem, landedAs landed: FileItem, from origin: FileItem.ID, mode: TransferMode
    ) -> UndoRecord {
        mode == .move
            ? .relocate([Relocation(item: landed.id, folder: origin, name: item.name)])
            : .trash([landed.id])
    }

    /// The bytes each item will copy: all of a copy and of a move to another
    /// volume, none of a move within the volume, which is a rename.
    private func bytesToCopy(_ items: [FileItem], to folder: FileItem.ID, mode: TransferMode)
        async throws -> [Int64]
    {
        let volume = try await operations.item(at: folder).volume
        var sizes: [Int64] = []
        for item in items {
            let copies = mode == .copy || item.volume != volume
            sizes.append(copies ? try await operations.byteCount(of: item) : 0)
        }
        return sizes
    }

    private func decide(_ existing: FileItem, _ incoming: FileItem, copyingInPlace: Bool) async
        -> ConflictDecision
    {
        copyingInPlace ? .keepBoth : await resolver.decide(existing: existing, incoming: incoming)
    }

    private func keyed(_ items: some Sequence<FileItem>) -> [String: FileItem] {
        Dictionary(items.map { (ConflictResolver.comparisonKey($0.name), $0) }) { first, _ in first
        }
    }

    /// The undo record runs the steps backwards, so a replaced item comes back
    /// only after the item that replaced it has moved out.
    private func result(_ items: [FileItem], _ undo: [UndoRecord], stopped: Bool) -> OperationResult
    {
        OperationResult(items: items, undo: .sequence(undo.reversed()), stopped: stopped)
    }
}
