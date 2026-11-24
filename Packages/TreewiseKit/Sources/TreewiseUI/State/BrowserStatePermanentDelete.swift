import TreewiseCore

/// Deleting for good, where a location has no Trash (ADR 0128).
extension BrowserState {
    /// As a Move to Trash of `items` fails, keeps those it did not move when it failed for
    /// want of a Trash, for the user to delete for good instead: the item it failed on and
    /// those after it, as it moves them in order and stops at the first it cannot move.
    func offerToDeletePermanently(_ items: [FileItem], after failure: FileSystemError) {
        guard case .trashUnavailable(let id) = failure,
            let index = items.firstIndex(where: { $0.id == id })
        else { return }
        itemsWithoutTrash = Array(items[index...])
    }

    /// Deletes items for good, as the user confirmed; it registers no undo, as there is
    /// none. The items go off the clipboard and out of the tabs' histories.
    public func deletePermanently(_ items: [FileItem]) async {
        itemsWithoutTrash = []
        guard !items.isEmpty else { return }
        let ids = items.map(\.id)
        let deleted = await perform(
            name: "", undoManager: nil, touching: Set(items.compactMap(\.parentID))
        ) { operations in
            for id in ids {
                try Task.checkCancellation()
                try await operations.deletePermanently(id)
            }
            return OperationResult(items: [], undo: .none)
        }
        guard deleted != nil else { return }
        clipboard = clipboard?.removing(Set(ids))
        moveTabs(awayFrom: items)
        await reloadShownFolders()
    }
}
