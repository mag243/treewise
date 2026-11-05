import AppKit
import TreewiseUI

/// A rename that a click on a selected name starts once the double-click
/// interval passes without a second click (ADR 0039). The list and the icon
/// view each hold one; a new click or a key press cancels it.
@MainActor
final class PendingRename {
    private var task: Task<Void, Never>?
    /// Set by the view when a drag of its items begins during a click.
    var dragged = false

    /// Starts `rename` after the wait if `click` renames, and if `isStillValid`
    /// holds by then: the same selection, in the key window.
    func schedule(
        _ click: ClickRename, isStillValid: @escaping @MainActor () -> Bool,
        rename: @escaping @MainActor () -> Void
    ) {
        cancel()
        guard click.begins else { return }
        task = Task {
            try? await Task.sleep(for: .seconds(NSEvent.doubleClickInterval))
            guard !Task.isCancelled, isStillValid() else { return }
            rename()
        }
    }

    /// Stops a rename that is waiting.
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Whether `event` holds ⌘, ⇧, ⌥ or ⌃.
    static func hasModifiers(_ event: NSEvent) -> Bool {
        !event.modifierFlags.isDisjoint(with: [.command, .shift, .option, .control])
    }

    /// Whether `point`, in `field`'s coordinates, is on its left-aligned text
    /// rather than the empty part after it.
    static func isOnText(_ point: NSPoint, in field: NSTextField) -> Bool {
        field.bounds.contains(point) && point.x <= field.attributedStringValue.size().width
    }
}
