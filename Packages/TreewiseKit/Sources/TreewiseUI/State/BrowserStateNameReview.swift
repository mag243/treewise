import Foundation
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface

extension BrowserState {
    /// Whether names can be suggested for what the focused pane shows.
    public var canSuggestNames: Bool { operations != nil && canAddItems }

    /// A review of the selection, or of the focused folder's files when nothing is selected.
    public func makeNameReview(
        host: any NameModuleHosting, store: any FolderSettingsStoring
    ) async -> NameReviewModel? {
        guard let operations,
            let folder = try? await fileSystem.item(at: layout.focusedPane.activeTab.folder)
        else { return nil }
        let builder = NameRequestBuilder()
        let selection = selectedItems
        return NameReviewModel(
            folder: folder, scope: selection.isEmpty ? .wholeFolder : .selection,
            selection: selection,
            dependencies: .init(
                operations: operations, host: host, store: store,
                makeRequest: { item, siblings, needed in
                    // Reading a scan is slow, so it happens away from the main actor.
                    await Task.detached {
                        builder.request(for: item, siblings: siblings, neededContent: needed)
                    }.value
                }))
    }

    /// Registers the undo of what a review applied, and shows the new names.
    public func finishNameReview(_ outcome: BatchRenameOutcome, undoManager: UndoManager?) async {
        guard !outcome.renamed.isEmpty else { return }
        registerUndo(
            Task { outcome.undo }, name: Self.actionName("Rename"), undoManager: undoManager)
        await relocateFavorites(outcome.renamed.map { ($0.original, $0.item.id) })
        await reloadShownFolders()
    }
}
