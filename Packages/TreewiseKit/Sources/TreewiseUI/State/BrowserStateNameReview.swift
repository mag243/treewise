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
        await makeNameReview(of: selectedItems, host: host, store: store)
    }

    /// Whether proposals can be asked for while renaming this item: one file in a folder
    /// whose items can change (ADR 0066).
    public func canSuggestName(for item: FileItem) -> Bool {
        canSuggestNames && !item.isContainer && item.canBeRenamedOrTrashed
    }

    /// The proposals for one file being renamed, as a review of that file alone (ADR 0066).
    public func makeNameProposals(
        for item: FileItem, host: any NameModuleHosting, store: any FolderSettingsStoring
    ) async -> NameReviewModel? {
        guard canSuggestName(for: item) else { return nil }
        return await makeNameReview(of: [item], host: host, store: store)
    }

    private func makeNameReview(
        of selection: [FileItem], host: any NameModuleHosting, store: any FolderSettingsStoring
    ) async -> NameReviewModel? {
        guard let operations,
            let folder = try? await fileSystem.item(at: layout.focusedPane.activeTab.folder)
        else { return nil }
        let builder = NameRequestBuilder()
        return NameReviewModel(
            folder: folder, scope: selection.isEmpty ? .wholeFolder : .selection,
            selection: selection,
            dependencies: .init(
                operations: operations, host: host, store: store,
                defaultPattern: settings.defaultNamePattern,
                personalDataInNames: settings.personalDataInNames,
                addOns: settings.addOns,
                licence: { [licences] in licences?.context() ?? .none },
                startTrial: { [licences] in licences?.startTrial() ?? .none },
                savedPatterns: { [settings] in settings.savedPatterns },
                savePattern: { [settings] name, text in
                    if case .failure(let problem) = settings.savedPatterns.save(
                        name: name, text: text)
                    {
                        return problem
                    }
                    return nil
                },
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
