import SwiftUI

/// The Edit menu's Undo and Redo, for the file operations of all windows
/// (`SharedUndo`, ADR 0037).
struct UndoCommands: Commands {
    let undo: SharedUndo

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(undo.isEditingText ? String(localized: "Undo") : undo.undoTitle) {
                undo.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!undo.isEditingText && !undo.canUndo)
            Button(undo.isEditingText ? String(localized: "Redo") : undo.redoTitle) {
                undo.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!undo.isEditingText && !undo.canRedo)
        }
    }
}

extension EnvironmentValues {
    /// The undo manager file operations register with: one for all windows.
    @Entry var fileUndoManager: UndoManager?
}
