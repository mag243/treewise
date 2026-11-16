import Foundation

/// One undo history for the whole app, as on the Mac (ADR 0047): every window's operations
/// register in it, and the system's Undo and Redo, with ⌘Z, ⇧⌘Z and the three-finger swipe,
/// take from it whatever window is in front.
@MainActor
final class SharedUndo {
    /// The history every operation registers its undo in.
    let manager = UndoManager()
}
