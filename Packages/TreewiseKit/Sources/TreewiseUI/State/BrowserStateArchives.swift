import Foundation
import TreewiseCore

extension BrowserState {
    /// Whether the selection is one archive that can be extracted (ADR 0074).
    public var canExtractSelection: Bool {
        let items = selectedItems
        return archives != nil && items.count == 1
            && ArchiveNaming.isArchive(name: items[0].name, kind: items[0].kind)
    }

    /// Whether the selection can go into a new archive beside it (ADR 0074).
    public var canCompressSelection: Bool {
        let items = selectedItems
        return archives != nil && canAddItems && !items.isEmpty && items.allSatisfy(\.isMovable)
            && Set(items.map(\.parentID)).count == 1
    }

    /// Extracts the selected archive to a new folder in `folder`, named after
    /// the archive, and selects it when the pane shows `folder`.
    public func extractSelection(to folder: FileItem.ID, undoManager: UndoManager?) async {
        guard canExtractSelection, let operations, let archive = selectedItems.first else {
            return
        }
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

    /// Runs an archive operation as the window's transfer, with the progress
    /// panel, pause and stop. A stop is no failure: nothing new exists then.
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
        // A window runs one transfer at a time; a second one waits for the first.
        if let running = runningTransfer { _ = await running.value }
        let control = TransferControl()
        let reporter = archiveReporter(kind)
        let task = Task {
            await perform(name: name, undoManager: undoManager) { _ in
                do {
                    let created = try await work(archives, reporter, control)
                    return OperationResult(items: [created], undo: .trash([created.id]))
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
        return result?.items.first
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
