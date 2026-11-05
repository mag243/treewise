import AppKit
import Observation

/// The undo history of file operations, shared by all windows (ADR 0037):
/// one `UndoManager`, and what the Edit menu's Undo and Redo show for it.
/// While a text field is being edited, Undo and Redo go to the field.
@MainActor
@Observable
final class SharedUndo {
    /// The undo manager every window's file operations register with.
    @ObservationIgnored let manager = UndoManager()
    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var undoTitle = ""
    private(set) var redoTitle = ""
    /// Whether a text field is being edited, whose own undo then comes first.
    private(set) var isEditingText = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        let changes: [Notification.Name] = [
            .NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
        ]
        for name in changes {
            observers.append(
                center.addObserver(forName: name, object: manager, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
        }
        for (name, editing) in [
            (NSText.didBeginEditingNotification, true), (NSText.didEndEditingNotification, false),
        ] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.isEditingText = editing }
                })
        }
        refresh()
    }

    /// Undoes the last file operation, or the last change to the text being
    /// edited.
    func undo() {
        if isEditingText {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        } else {
            manager.undo()
        }
    }

    /// Redoes what was undone last, in the text being edited or of the files.
    func redo() {
        if isEditingText {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        } else {
            manager.redo()
        }
    }

    private func refresh() {
        canUndo = manager.canUndo
        canRedo = manager.canRedo
        undoTitle = manager.undoMenuItemTitle
        redoTitle = manager.redoMenuItemTitle
    }
}
