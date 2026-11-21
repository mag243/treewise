import UIKit

/// The table's collection view: the first responder in its window, so the system's Undo and
/// Redo, from the keyboard, the menu bar and the three-finger swipe, take from the app's one
/// history rather than the window's own (ADR 0047), and the keyboard's commands on the list
/// reach it (ADR 0135): its own keys, and the menu's commands sent down the responder chain.
final class FolderCollectionView: UICollectionView {
    var sharedUndo: UndoManager?
    /// Whether the last touch was the pointer's, a click, rather than a finger's (ADR 0136).
    private(set) var isPointerTouch = false
    /// The keys held with the last touch.
    private(set) var pointerModifiers: UIKeyModifierFlags = []
    /// Carries out the keyboard's commands.
    weak var keys: FolderCollectionCoordinator?

    override var undoManager: UndoManager? { sharedUndo }

    override var canBecomeFirstResponder: Bool { true }

    /// The list takes no typing, so it has an input view of its own with nothing in it: on
    /// iOS 27 a menu that opens brings up the first responder's input view, which is the
    /// keyboard unless the responder has one.
    override var inputView: UIView? {
        if #available(iOS 27, *) { return noInput }
        return super.inputView
    }

    private lazy var noInput = UIView(frame: .zero)

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if #available(iOS 27, *) {
            // Nor the bar of shortcuts an iPad shows above an input view.
            inputAssistantItem.leadingBarButtonGroups = []
            inputAssistantItem.trailingBarButtonGroups = []
        }
        if window != nil { becomeFirstResponder() }
    }

    /// A touch in the table takes the keyboard back, as an alert or the search field may
    /// have held it, so Undo reaches the app's history again.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isPointerTouch = touches.first?.type == .indirectPointer
        pointerModifiers = event?.modifierFlags ?? []
        if !isFirstResponder { becomeFirstResponder() }
        super.touchesBegan(touches, with: event)
    }

    /// The list's own keys; ⌘↑ is here as well as in the Go menu, as the collection view
    /// keeps it for scrolling on iOS 18.
    override var keyCommands: [UIKeyCommand]? {
        return [
            Self.key(UIKeyCommand.inputUpArrow, #selector(selectAbove)),
            Self.key(UIKeyCommand.inputDownArrow, #selector(selectBelow)),
            Self.key(UIKeyCommand.inputUpArrow, #selector(extendAbove), .shift),
            Self.key(UIKeyCommand.inputDownArrow, #selector(extendBelow), .shift),
            Self.key(" ", #selector(quickLook)),
            Self.key("\r", #selector(renameSelection(_:))),
            Self.key(UIKeyCommand.f2, #selector(renameSelection(_:))),
            Self.key(UIKeyCommand.inputEscape, #selector(stopSelecting)),
            Self.key(UIKeyCommand.inputUpArrow, #selector(goToEnclosingFolder), .command),
            Self.key(UIKeyCommand.inputDownArrow, #selector(openSelection(_:)), .command),
            Self.key(
                UIKeyCommand.inputDownArrow, #selector(openSelectionInNewWindow(_:)),
                [.command, .alternate]),
            Self.key("\u{8}", #selector(moveSelectionToTrash(_:)), .command),
        ]
    }

    private static func key(
        _ input: String, _ action: Selector, _ modifiers: UIKeyModifierFlags = []
    ) -> UIKeyCommand {
        let command = UIKeyCommand(input: input, modifierFlags: modifiers, action: action)
        command.wantsPriorityOverSystemBehavior = true
        return command
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if let keys, keys.handles(action) { return keys.canPerform(action) }
        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: - The list's keys

    @objc private func selectAbove() { keys?.moveSelection(.up, extending: false) }
    @objc private func selectBelow() { keys?.moveSelection(.down, extending: false) }
    @objc private func extendAbove() { keys?.moveSelection(.up, extending: true) }
    @objc private func extendBelow() { keys?.moveSelection(.down, extending: true) }
    @objc private func quickLook() { keys?.quickLook() }
    @objc private func stopSelecting() { keys?.stopSelecting() }
    @objc private func goToEnclosingFolder() { keys?.goToEnclosingFolder() }

    // MARK: - The menus' commands, sent down the responder chain

    override func cut(_ sender: Any?) { keys?.cut() }
    override func copy(_ sender: Any?) { keys?.copy() }
    override func paste(_ sender: Any?) { keys?.paste() }
    override func selectAll(_ sender: Any?) { keys?.selectAll() }
    override func find(_ sender: Any?) { keys?.find() }
    override func toggleSidebar(_ sender: Any?) { keys?.toggleSidebar() }
    @objc func openSelection(_ sender: Any?) { keys?.openSelection() }
    @objc func openSelectionInNewWindow(_ sender: Any?) { keys?.openSelectionInNewWindow() }
    @objc func renameSelection(_ sender: Any?) { keys?.renameSelection() }
    @objc func moveSelectionToTrash(_ sender: Any?) { keys?.moveSelectionToTrash() }
    @objc func moveItemHere(_ sender: Any?) { keys?.moveItemHere() }
}
