import Foundation
import TreewiseCore

/// The commands a swipe over a row shows (ADR 0146), taken from the context menu's, so the
/// two say and do the same.
struct SwipeCommands {
    /// To the left, first and performed by a full swipe; nil where the item cannot be trashed.
    let moveToTrash: ItemCommand?
    /// To the left after it, in More…'s action sheet: the row's other commands that apply.
    let more: [ItemCommand]
    /// To the right, Cut first and performed by a full swipe, then Copy; none where the
    /// item cannot be moved.
    let leading: [ItemCommand]
}

extension ItemCommands {
    /// The swipe's commands for `item`, from its context menu's.
    static func swipes(for item: FileItem, actions: ItemActions) -> SwipeCommands {
        let commands = sections(for: [item], actions: actions).flatMap { $0 }
            .filter { $0.isEnabled && $0.children.isEmpty }
        let titled = { (title: String) in commands.first { $0.title == title } }
        let more = [
            String(localized: "Share…"), String(localized: "Rename"),
            String(localized: "Rename with Suggestions…"), String(localized: "Move to…"),
            String(localized: "Copy to…"), String(localized: "Add to Favorites"),
            String(localized: "Remove from Favorites"),
        ].compactMap(titled)
        return SwipeCommands(
            moveToTrash: titled(String(localized: "Move to Trash")), more: more,
            leading: [String(localized: "Cut"), String(localized: "Copy")].compactMap(titled))
    }
}
