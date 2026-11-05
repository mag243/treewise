import Foundation
import TreewiseCore

extension BrowserState {
    /// Registers the undo of an operation whose record `record` delivers.
    ///
    /// `UndoManager` calls its handlers synchronously and expects the redo to
    /// be registered during the undo, while the undo itself is async. So each
    /// handler starts the inverse in a task and at once registers the next
    /// step, which waits for that task's record (ADR 0018).
    func registerUndo(_ record: Task<UndoRecord, Never>, name: String, undoManager: UndoManager?) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { browser in
            let inverse = Task { @MainActor in await browser.performUndo(record.value) }
            browser.registerUndo(inverse, name: name, undoManager: undoManager)
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
            failure = error as? FileSystemError
            await reloadShownFolders()
            return .none
        }
    }
}
