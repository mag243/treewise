import Foundation
import TreewiseCore

/// A command of the context menu: its title, symbol and what it does, so the SwiftUI list
/// and the UIKit table show the same menu (ADR 0047, 0116).
struct ItemCommand: Identifiable {
    let title: String
    let symbol: String
    var isDestructive = false
    var isEnabled = true
    let perform: () -> Void

    var id: String { title }
}

/// The context menu of the items a long press or secondary click is on, or of the folder
/// when it is on empty space, in sections.
@MainActor
enum ItemCommands {
    static func sections(for items: [FileItem], actions: ItemActions) -> [[ItemCommand]] {
        items.isEmpty ? [folderCommands(actions)] : itemCommands(items, actions)
    }

    private static func itemCommands(_ items: [FileItem], _ actions: ItemActions)
        -> [[ItemCommand]]
    {
        var sections: [[ItemCommand]] = []
        if let item = items.first, items.count == 1 {
            sections.append([
                ItemCommand(
                    title: item.isContainer
                        ? String(localized: "Open") : String(localized: "Quick Look"),
                    symbol: item.isContainer ? "folder" : "eye",
                    perform: { actions.open(item) }),
                ItemCommand(
                    title: String(localized: "Rename"), symbol: "pencil",
                    isEnabled: item.canBeRenamedOrTrashed, perform: { actions.rename(item) }),
            ])
        }
        if actions.canSuggestNames {
            sections.append(namingCommands(items, actions))
        }
        let movable = items.allSatisfy(\.isMovable)
        sections.append([
            ItemCommand(
                title: String(localized: "Cut"), symbol: "scissors", isEnabled: movable,
                perform: { actions.cut(items) }),
            ItemCommand(
                title: String(localized: "Copy"), symbol: "doc.on.doc", isEnabled: movable,
                perform: { actions.copy(items) }),
        ])
        sections.append([
            ItemCommand(
                title: String(localized: "Move to Trash"), symbol: "trash", isDestructive: true,
                isEnabled: items.allSatisfy(\.canBeRenamedOrTrashed),
                perform: { actions.moveToTrash(items) })
        ])
        return sections
    }

    /// The name overview, and for one file Rename with Suggestions (ADR 0130).
    private static func namingCommands(_ items: [FileItem], _ actions: ItemActions)
        -> [ItemCommand]
    {
        var commands = [
            ItemCommand(
                title: String(localized: "Suggest Names…"), symbol: "text.badge.star",
                perform: { actions.suggestNames(for: items) })
        ]
        if let item = items.first, items.count == 1, actions.canSuggestName(for: item) {
            commands.append(
                ItemCommand(
                    title: String(localized: "Rename with Suggestions…"),
                    symbol: "character.cursor.ibeam",
                    perform: { actions.rename(item, suggests: true) }))
        }
        return commands
    }

    private static func folderCommands(_ actions: ItemActions) -> [ItemCommand] {
        [
            ItemCommand(
                title: String(localized: "New Folder"), symbol: "folder.badge.plus",
                isEnabled: actions.canAddItems, perform: actions.newFolder),
            ItemCommand(
                title: String(localized: "Paste"), symbol: "doc.on.clipboard",
                isEnabled: actions.canPaste, perform: actions.paste),
            ItemCommand(
                title: String(localized: "Suggest Names for Whole Folder…"),
                symbol: "text.badge.star", isEnabled: actions.canSuggestNames,
                perform: { actions.suggestNames(true) }),
        ]
    }
}
