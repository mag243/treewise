import Foundation
import TreewiseCore

extension BrowserState {
    /// Registers the undo of an operation whose record `record` delivers.
    ///
    /// `UndoManager` calls its handlers synchronously and expects the redo to
    /// be registered during the undo, while the undo itself is async. So each
    /// handler starts the inverse in a task and at once registers the next
    /// step, which waits for that task's record (ADR 0018).
    ///
    /// `alongside` is what the same step changes beside the files, undone after them and
    /// redone after them (ADR 0139).
    func registerUndo(
        _ record: Task<UndoRecord, Never>, name: String, undoManager: UndoManager?,
        alongside: UndoAlongside? = nil
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { browser in
            let inverse = Task { @MainActor in
                let redo = await browser.performUndo(record.value)
                await alongside?.undo()
                return redo
            }
            browser.registerUndo(
                inverse, name: name, undoManager: undoManager, alongside: alongside?.reversed)
        }
        undoManager.setActionName(name)
    }

    /// Performs an undo record and returns the record that redoes it.
    private func performUndo(_ record: UndoRecord) async -> UndoRecord {
        guard let operations else { return .none }
        do {
            let result = try await operations.undo(record)
            failure = nil
            if case .relocate(let relocations) = record,
                relocations.count == result.items.count
            {
                await relocateFavorites(
                    Array(zip(relocations.map(\.item), result.items.map(\.id))))
            }
            await reloadShownFolders()
            return result.undo
        } catch {
            failure = FileSystemError(error)
            await reloadShownFolders()
            return .none
        }
    }
}

/// What one undoable step changes beside the files, as a template corrected along with the
/// folders renamed (ADR 0139): how to undo it, and how to redo it.
struct UndoAlongside: Sendable {
    let undo: @MainActor @Sendable () async -> Void
    let redo: @MainActor @Sendable () async -> Void

    /// The same change the other way, for the step that redoes it.
    var reversed: UndoAlongside { UndoAlongside(undo: redo, redo: undo) }
}
