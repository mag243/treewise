import Foundation
import TreewiseCore

extension BrowserState {
    /// The selected items of the focused pane's active tab, in list order.
    public var selectedItems: [FileItem] {
        let tab = layout.focusedPane.activeTabID
        let selection = content(of: tab).selection
        return visibleItems(of: tab).filter { selection.contains($0.id) }
    }

    /// Whether the selection is one item that can be renamed.
    public var canRenameSelection: Bool {
        let items = selectedItems
        return items.count == 1 && items.allSatisfy(\.canBeRenamedOrTrashed)
    }

    /// Whether the selection has items and all of them can go to the Trash.
    public var canTrashSelection: Bool {
        let items = selectedItems
        return !items.isEmpty && items.allSatisfy(\.canBeRenamedOrTrashed)
    }

    /// Whether the selection has items and all of them can be cut or copied.
    public var canCutOrCopySelection: Bool {
        let items = selectedItems
        return !items.isEmpty && items.allSatisfy(\.isMovable)
    }

    /// Puts the selection on the clipboard to be moved (⌘X), unless an item
    /// of it cannot be moved.
    public func cutSelection() {
        guard canCutOrCopySelection else { return }
        clipboard = ClipboardModel(items: selectedItems, mode: .cut)
    }

    /// Puts the selection on the clipboard to be copied (⌘C), unless an item
    /// of it cannot be copied.
    public func copySelection() {
        guard canCutOrCopySelection else { return }
        clipboard = ClipboardModel(items: selectedItems, mode: .copy)
    }

    /// Pastes the clipboard into the focused pane's folder (⌘V): cut items
    /// move and leave the clipboard empty, copied items stay on it.
    public func paste(resolver: any ConflictResolving, undoManager: UndoManager?) async {
        guard let clipboard, canAddItems else { return }
        let folder = layout.focusedPane.activeTab.folder
        let done = await transfer(
            clipboard.items, to: folder, mode: clipboard.transferMode, resolver: resolver,
            undoManager: undoManager)
        if done && clipboard.mode == .cut { self.clipboard = nil }
    }

    /// Pastes items from outside Treewise, such as files copied in Finder, into
    /// the focused pane's folder; they are always copied.
    public func pasteItems(
        _ items: [FileItem], resolver: any ConflictResolving, undoManager: UndoManager?
    ) async {
        guard canAddItems else { return }
        let folder = layout.focusedPane.activeTab.folder
        await transfer(items, to: folder, mode: .copy, resolver: resolver, undoManager: undoManager)
    }

    /// Drops items on a folder: they move or copy as the drag rules decide
    /// (ADR 0003); nothing happens where they may not be dropped.
    public func drop(
        _ items: [FileItem], onto target: FileItem, modifiers: DropModifiers,
        resolver: any ConflictResolving,
        undoManager: UndoManager?
    ) async {
        let ancestry = (try? await fileSystem.ancestorIDs(of: target.id)) ?? []
        guard
            let mode = TransferPlanner.plan(
                items: items, target: target, modifiers: modifiers, ancestry: { _ in ancestry })
        else { return }
        await transfer(
            items, to: target.id, mode: mode, resolver: resolver, undoManager: undoManager)
    }

    /// Moves the items on the clipboard into the focused pane's folder, also
    /// when they were copied, and empties the clipboard: ⌥⌘V (ADR 0022).
    public func moveHere(resolver: any ConflictResolving, undoManager: UndoManager?) async {
        guard let clipboard else { return }
        let folder = layout.focusedPane.activeTab.folder
        let done = await transfer(
            clipboard.items, to: folder, mode: .move, resolver: resolver, undoManager: undoManager)
        if done { self.clipboard = nil }
    }

    /// Copies or moves the selection into `folder`, such as the folder of the
    /// other window: Copy and Move to Other Window (ADR 0037). The drag rules
    /// decide whether it may go there, as for a drop with ⌥ or ⌘.
    public func send(
        selectionTo folder: FileItem.ID, mode: TransferMode, resolver: any ConflictResolving,
        undoManager: UndoManager?
    ) async {
        let items = selectedItems
        guard !items.isEmpty, let target = try? await fileSystem.item(at: folder) else { return }
        await drop(
            items, onto: target, modifiers: mode == .copy ? .option : .command,
            resolver: resolver, undoManager: undoManager)
    }

    /// Stops the running transfer after the item in progress; a partial copy
    /// of that item is removed, what was done before stays done and undoable.
    public func cancelOperation() {
        runningControl?.stop()
        runningTransfer?.cancel()
    }

    /// Holds the running transfer at its next file or block (ADR 0026).
    public func pauseOperation() {
        guard let runningControl else { return }
        runningControl.pause()
        isPaused = true
    }

    /// Lets a paused transfer go on.
    public func resumeOperation() {
        runningControl?.resume()
        isPaused = false
    }

    /// Passes a transfer's progress on to `progress` while that transfer
    /// runs; progress arriving after it ended is dropped, so it cannot bring
    /// the panel back.
    private func reporter() -> @Sendable (OperationProgress) -> Void {
        { [weak self] progress in
            Task { @MainActor in
                guard let self, self.runningTransfer != nil else { return }
                self.progress = progress
            }
        }
    }

    /// Creates "untitled folder" in the focused pane's folder and selects it,
    /// so the list can start renaming it.
    @discardableResult
    public func newFolder(undoManager: UndoManager?, locale: Locale = .current) async -> FileItem? {
        guard canAddItems else { return nil }
        let folder = layout.focusedPane.activeTab.folder
        let result = await perform(name: Self.actionName("New Folder"), undoManager: undoManager) {
            try await $0.createUntitledFolder(in: folder, locale: locale)
        }
        selectInFocusedTab(result?.items ?? [])
        renameRequest = result?.items.first?.id
        return result?.items.first
    }

    /// Renames an item, unless it is one that keeps its name (ADR 0049).
    public func rename(_ item: FileItem, to name: String, undoManager: UndoManager?) async {
        guard name != item.name, item.canBeRenamedOrTrashed else { return }
        let result = await perform(name: Self.actionName("Rename"), undoManager: undoManager) {
            try await $0.rename(item, to: name)
        }
        if let renamed = result?.items.first {
            await relocateFavorites([(item.id, renamed.id)])
        }
        selectInFocusedTab(result?.items ?? [])
    }

    /// Moves the focused pane's selection to the Trash (⌘⌫), unless an item
    /// of it cannot go there (ADR 0049).
    public func moveSelectionToTrash(undoManager: UndoManager?) async {
        guard canTrashSelection else { return }
        let items = selectedItems
        let ids = items.map(\.id)
        let trashed = await perform(
            name: Self.actionName("Move to Trash"), undoManager: undoManager
        ) {
            try await $0.moveToTrash(ids)
        }
        guard trashed != nil else { return }
        clipboard = clipboard?.removing(Set(ids))
        moveTabs(awayFrom: items)
        await reloadShownFolders()
    }

    /// Takes removed items out of every tab's history; a tab that shows one of
    /// them, or a folder inside one, goes to the folder the item was in.
    private func moveTabs(awayFrom removed: [FileItem]) {
        let ids = Set(removed.map(\.id))
        for tab in layout.panes.flatMap(\.tabs) {
            let ancestry = content(of: tab.id).ancestry
            let gone = removed.first { $0.id == tab.folder || ancestry.contains($0.id) }
            let fallback = gone?.parentID ?? tab.folder
            guard !ids.contains(fallback) else { continue }
            layout.updateTab(tab.id) { $0.history.removeItems(ids, fallback: fallback) }
            if gone != nil { contents[tab.id] = TabContent() }
        }
    }

    @discardableResult
    private func transfer(
        _ items: [FileItem], to folder: FileItem.ID, mode: TransferMode,
        resolver: any ConflictResolving,
        undoManager: UndoManager?
    ) async -> Bool {
        // A paste has no drop rules before it; items may come from outside Treewise.
        guard items.allSatisfy(\.isMovable) else { return false }
        let name = Self.actionName(mode == .move ? "Move" : "Copy")
        // A window runs one transfer at a time; a second one waits for the first.
        if let running = runningTransfer { _ = await running.value }
        let control = TransferControl()
        let task = Task {
            await perform(name: name, undoManager: undoManager) { operations in
                try await operations.transfer(
                    items, to: folder, mode: mode, resolver: resolver, progress: reporter(),
                    control: control)
            }
        }
        runningTransfer = task
        runningControl = control
        let result = await task.value
        runningTransfer = nil
        runningControl = nil
        progress = nil
        isPaused = false
        if mode == .move, let result {
            clipboard = clipboard?.removing(
                Set(items.map(\.id)).subtracting(result.items.map(\.id)))
            // A stopped move has fewer results, and then which went where is unknown.
            if result.items.count == items.count {
                await relocateFavorites(Array(zip(items.map(\.id), result.items.map(\.id))))
            }
        }
        if layout.focusedPane.activeTab.folder == folder { selectInFocusedTab(result?.items ?? []) }
        return result != nil
    }

    /// Runs an operation, registers its undo, reloads what the panes show and
    /// records a failure. Returns `nil` when the operation failed.
    @discardableResult
    func perform(
        name: String, undoManager: UndoManager?,
        _ operation: (any FileOperating) async throws -> OperationResult
    ) async -> OperationResult? {
        guard let operations else { return nil }
        do {
            let result = try await operation(operations)
            failure = nil
            registerUndo(Task { result.undo }, name: name, undoManager: undoManager)
            await reloadShownFolders()
            return result
        } catch {
            failure = error as? FileSystemError ?? .unexpected(error.localizedDescription)
            await reloadShownFolders()
            return nil
        }
    }

    func selectInFocusedTab(_ items: [FileItem]) {
        guard !items.isEmpty else { return }
        setSelection(Set(items.map(\.id)), in: layout.focusedPane.activeTabID)
        revealRequest = items[0].id
    }

    func reloadShownFolders() async {
        await reloadFavorites()
        for pane in layout.panes {
            await load(pane.activeTabID)
        }
    }

    /// The name of an undoable action, as the Edit menu shows it after "Undo".
    static func actionName(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }
}
