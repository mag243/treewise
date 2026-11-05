/// What applying a batch of renames did (ADR 0057).
public struct BatchRenameOutcome: Sendable {
    /// An item that has its new name.
    public struct Renamed: Hashable, Sendable {
        /// The item's identity before the batch.
        public let original: FileItem.ID
        /// The item now.
        public let item: FileItem
    }

    /// Why the batch stopped.
    public struct Failure: Hashable, Sendable {
        /// The item it stopped at, by its identity before the batch.
        public let item: FileItem.ID
        /// What went wrong.
        public let error: FileSystemError
        /// The temporary name of an item that was moved aside and not yet back.
        public let leftUnderTemporaryName: String?
    }

    /// The items renamed, in the order they got their names.
    public let renamed: [Renamed]
    /// Undoes all that was done, as one step.
    public let undo: UndoRecord
    /// Why the batch stopped early, if it did.
    public let failure: Failure?
}

extension FileOperating {
    /// Runs planned steps in order, and stops at the first that fails. What was done stays
    /// done and can be undone. A name that came up meanwhile stops the step and is not
    /// replaced. Names are the disk's, so a `:` from Finder's `/` is allowed here.
    public func applyBatch(_ steps: [BatchRenameStep]) async -> BatchRenameOutcome {
        var current: [FileItem.ID: FileItem.ID] = [:]
        var undo: [Relocation] = []
        var renamed: [BatchRenameOutcome.Renamed] = []
        for step in steps {
            do {
                let item = try await self.item(at: current[step.item] ?? step.item)
                let moved = try await rename(item, toDiskName: step.to)
                current[step.item] = moved.id
                undo.insert(
                    Relocation(item: moved.id, folder: item.parentID ?? moved.id, name: step.from),
                    at: 0)
                renamed.removeAll { $0.original == step.item }
                renamed.append(.init(original: step.item, item: moved))
            } catch {
                let failure = BatchRenameOutcome.Failure(
                    item: step.item,
                    error: error as? FileSystemError ?? .unexpected(error.localizedDescription),
                    leftUnderTemporaryName: renamed.first {
                        $0.item.name.hasPrefix(BatchRenamePlanner.temporaryPrefix)
                    }?.item.name)
                return BatchRenameOutcome(
                    renamed: renamed, undo: .relocate(undo), failure: failure)
            }
        }
        return BatchRenameOutcome(renamed: renamed, undo: .relocate(undo), failure: nil)
    }

    private func rename(_ item: FileItem, toDiskName name: String) async throws -> FileItem {
        guard let folder = item.parentID else { throw FileSystemError.notWritable(item.id) }
        let key = ConflictResolver.comparisonKey(name)
        let taken = try await itemsByName(in: folder).values.contains {
            $0.id != item.id && ConflictResolver.comparisonKey($0.name) == key
        }
        guard !taken else { throw FileSystemError.alreadyExists(item.id) }
        return try await move(item, into: folder, as: name)
    }
}
