import AppKit
import SwiftUI

/// The undo history of file operations, shared by all windows (ADR 0037):
/// every browser window returns this manager as its own, so the Edit menu's
/// Undo and Redo show and do the last file operation of any window, as
/// AppKit does for a window's undo manager (ADR 0081).
@MainActor
enum SharedUndo {
    /// The one history of all windows.
    static let manager = UndoManager()
}

extension EnvironmentValues {
    /// The undo manager file operations register with: one for all windows.
    @Entry var fileUndoManager: UndoManager?
}
