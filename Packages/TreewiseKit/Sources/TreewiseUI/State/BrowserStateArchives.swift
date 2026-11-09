import Foundation
import TreewiseCore

extension BrowserState {
    /// Whether Extract All has an archive: the selected one, or inside an
    /// archive that archive (ADR 0074, ADR 0076).
    public var canExtractSelection: Bool {
        guard archives != nil else { return false }
        if shownArchive != nil { return true }
        let items = selectedItems
        return items.count == 1 && ArchiveNaming.isArchive(name: items[0].name, kind: items[0].kind)
    }

    /// The archive Extract All extracts.
    public func archiveToExtract() async -> FileItem? {
        guard canExtractSelection else { return nil }
        if let shownArchive { return try? await fileSystem.item(at: shownArchive) }
        return selectedItems.first
    }

    /// The archive the focused pane shows inside of, if it does.
    var shownArchive: FileItem.ID? {
        ArchivePath(layout.focusedPane.activeTab.folder)?.archive
    }

    /// Whether the selection can go into a new archive beside it (ADR 0074).
    public var canCompressSelection: Bool {
        let items = selectedItems
        return archives != nil && canAddItems && shownArchive == nil && !items.isEmpty
            && items.allSatisfy(\.isMovable)
            && Set(items.map(\.parentID)).count == 1
    }

    /// Extracts the archive Extract All has to a new folder in `folder`, named after
    /// the archive, and selects it when the pane shows `folder`.
    public func extractSelection(to folder: FileItem.ID, undoManager: UndoManager?) async {
        guard let operations, let archive = await archiveToExtract() else { return }
        let created = await runArchiveOperation(
            name: Self.actionName("Extract"), kind: .extracting, undoManager: undoManager
        ) { archives, onProgress, control in
            let name = ArchiveNaming.extractionFolderName(
                for: archive.name, among: try await operations.itemsByName(in: folder).keys)
            return try await archives.extract(
                archive, into: folder, as: name, onProgress: onProgress, control: control)
        }
        if let created, layout.focusedPane.activeTab.folder == folder {
            selectInFocusedTab([created])
        }
    }

    /// Compresses the selection to a new archive beside it, named after its
    /// first item in the list, and starts renaming the archive.
    public func compressSelection(to format: ArchiveFormat, undoManager: UndoManager?) async {
        let items = selectedItems
        guard canCompressSelection, let operations, let first = items.first,
            let folder = first.parentID
        else { return }
        let created = await runArchiveOperation(
            name: Self.actionName("Compress"), kind: .compressing, undoManager: undoManager
        ) { archives, onProgress, control in
            let name = ArchiveNaming.newArchiveName(
                after: first.name, kind: first.kind, format: format,
                among: try await operations.itemsByName(in: folder).keys)
            return try await archives.compress(
                items, to: NewArchive(folder: folder, name: name, format: format),
                onProgress: onProgress, control: control)
        }
        guard let created else { return }
        selectInFocusedTab([created])
        renameRequest = created.id
    }

    /// Runs an archive operation that makes one item as the window's transfer.
    ///
    /// - Returns: what the operation made, or `nil` when it failed or stopped.
    private func runArchiveOperation(
        name: String, kind: OperationProgress.Kind, undoManager: UndoManager?,
        _ work:
            @escaping @Sendable (
                any ArchiveOperating, @escaping ArchiveProgressHandler, TransferControl
            )
            async throws -> FileItem
    ) async -> FileItem? {
        guard let archives else { return nil }
        @Sendable func makeOne(
            reporter: @escaping ArchiveProgressHandler, control: TransferControl
        ) async throws -> OperationResult {
            let created = try await work(archives, reporter, control)
            return OperationResult(items: [created], undo: .trash([created.id]))
        }
        let result = await runArchiveWork(
            name: name, kind: kind, undoManager: undoManager, makeOne)
        return result?.items.first
    }

    /// Runs archive work as the window's transfer, with the progress panel,
    /// pause and stop. A stop is no failure: nothing has changed then.
    ///
    /// - Returns: what the work came to, or `nil` when it failed.
    func runArchiveWork(
        name: String, kind: OperationProgress.Kind = .compressing, undoManager: UndoManager?,
        _ work:
            @escaping @Sendable (@escaping ArchiveProgressHandler, TransferControl) async throws
            -> OperationResult
    ) async -> OperationResult? {
        // A window runs one transfer at a time; a second one waits for the first.
        if let running = runningTransfer { _ = await running.value }
        let control = TransferControl()
        let reporter = archiveReporter(kind)
        let task = Task {
            await perform(name: name, undoManager: undoManager) { _ in
                do {
                    return try await work(reporter, control)
                } catch FileSystemError.cancelled {
                    return OperationResult(items: [], undo: .none, stopped: true)
                }
            }
        }
        runningTransfer = task
        runningControl = control
        progress = OperationProgress(completedBytes: 0, totalBytes: 0, kind: kind)
        let result = await task.value
        runningTransfer = nil
        runningControl = nil
        progress = nil
        isPaused = false
        return result
    }

    /// Passes an archive operation's progress on while it runs; what arrives
    /// after it ended is dropped, so it cannot bring the panel back.
    private func archiveReporter(_ kind: OperationProgress.Kind) -> ArchiveProgressHandler {
        { [weak self] entries in
            Task { @MainActor in
                guard let self, self.runningTransfer != nil else { return }
                self.progress = OperationProgress(
                    completedBytes: Int64(entries.completedEntries),
                    totalBytes: Int64(entries.totalEntries), currentName: entries.currentName,
                    kind: kind)
            }
        }
    }
}
