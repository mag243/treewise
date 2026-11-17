import Foundation
import Observation

/// One undo history for the whole app, as on the Mac (ADR 0047): every window's operations
/// register in it, and the system's Undo and Redo, with ⌘Z, ⇧⌘Z and the three-finger swipe,
/// take from it whatever window is in front. It follows the history, so that the toolbar's
/// Undo button shows whether and what it undoes (ADR 0125).
@MainActor
@Observable
final class SharedUndo {
    /// The history every operation registers its undo in.
    @ObservationIgnored let manager = UndoManager()
    /// Whether there is something to undo.
    private(set) var canUndo = false
    /// The menu title for what Undo would undo, such as "Undo Move".
    private(set) var undoTitle = ""
    @ObservationIgnored private var following: [Task<Void, Never>] = []

    /// The notifications after which what Undo undoes may have changed.
    private static let changes: [Notification.Name] = [
        .NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange,
        .NSUndoManagerDidRedoChange, .NSUndoManagerCheckpoint,
    ]

    init() {
        following = Self.changes.map { name in
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    self?.follow()
                }
            }
        }
        follow()
    }

    /// Undoes the last operation.
    func undo() {
        manager.undo()
        follow()
    }

    private func follow() {
        canUndo = manager.canUndo
        undoTitle = manager.undoMenuItemTitle
    }
}
