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
    /// The commands of a submenu, which this command opens instead of performing.
    var children: [ItemCommand] = []

    var id: String { title }

    /// A submenu of `children` (ADR 0142).
    static func submenu(_ title: String, symbol: String, _ children: [ItemCommand]) -> ItemCommand {
        ItemCommand(title: title, symbol: symbol, perform: {}, children: children)
    }
}

/// The context menu of the items a long press or secondary click is on, or of the folder
/// when it is on empty space, in sections.
@MainActor
enum ItemCommands {
    static func sections(for items: [FileItem], actions: ItemActions) -> [[ItemCommand]] {
        items.isEmpty
            ? [folderCommands(actions)] + shownFolderStructureCommands(actions)
            : itemCommands(items, actions)
    }

    private static func itemCommands(_ items: [FileItem], _ actions: ItemActions)
        -> [[ItemCommand]]
    {
        var sections: [[ItemCommand]] = []
        if let item = items.first, items.count == 1 {
            sections += singleItemCommands(item, actions)
        }
        if actions.canSuggestNames {
            sections.append(namingCommands(items, actions))
        }
        let movable = items.allSatisfy(\.isMovable)
        sections.append(
            [
                ItemCommand(
                    title: String(localized: "Cut"), symbol: "scissors", isEnabled: movable,
                    perform: { actions.cut(items) }),
                ItemCommand(
                    title: String(localized: "Copy"), symbol: "doc.on.doc", isEnabled: movable,
                    perform: { actions.copy(items) }),
            ] + moveToCommands(items, actions, isEnabled: movable)
                + shareCommands(items, actions))
        sections.append([
            ItemCommand(
                title: String(localized: "Move to Trash"), symbol: "trash", isDestructive: true,
                isEnabled: items.allSatisfy(\.canBeRenamedOrTrashed),
                perform: { actions.moveToTrash(items) })
        ])
        return sections
    }

    /// Open, Open in New Window where the device shows several windows (ADR 0134), Rename,
    /// and a folder's favorite.
    private static func singleItemCommands(_ item: FileItem, _ actions: ItemActions)
        -> [[ItemCommand]]
    {
        var opening = [
            ItemCommand(
                title: item.isContainer
                    ? String(localized: "Open") : String(localized: "Quick Look"),
                symbol: item.isContainer ? "folder" : "eye",
                perform: { actions.open(item) })
        ]
        if item.isContainer, let openInNewWindow = actions.openInNewWindow {
            opening.append(
                ItemCommand(
                    title: String(localized: "Open in New Window"),
                    symbol: "macwindow.badge.plus", perform: { openInNewWindow(item) }))
        }
        opening.append(
            ItemCommand(
                title: String(localized: "Rename"), symbol: "pencil",
                isEnabled: item.canBeRenamedOrTrashed, perform: { actions.rename(item) }))
        var sections = [opening]
        if item.isContainer, !item.id.isInsideArchive {
            sections.append([favoriteCommand(item, actions)])
        }
        sections += folderStructureCommands(item, actions)
        return sections
    }

    /// Move to… and Copy to…, where the width is compact and no second folder shows
    /// (ADR 0132).
    private static func moveToCommands(
        _ items: [FileItem], _ actions: ItemActions, isEnabled: Bool
    ) -> [ItemCommand] {
        guard let moveTo = actions.moveTo else { return [] }
        return [
            ItemCommand(
                title: String(localized: "Move to…"), symbol: "folder", isEnabled: isEnabled,
                perform: { moveTo(MoveToRequest(items: items, purpose: .move)) }),
            ItemCommand(
                title: String(localized: "Copy to…"), symbol: "doc.on.doc.fill",
                isEnabled: isEnabled,
                perform: { moveTo(MoveToRequest(items: items, purpose: .copy)) }),
        ]
    }

    /// Share…, where the width is compact (ADR 0132); an item inside an archive has no
    /// file of its own to share.
    private static func shareCommands(_ items: [FileItem], _ actions: ItemActions)
        -> [ItemCommand]
    {
        guard let share = actions.share else { return [] }
        return [
            ItemCommand(
                title: String(localized: "Share…"), symbol: "square.and.arrow.up",
                isEnabled: !items.contains { $0.id.isInsideArchive },
                perform: { share(items) })
        ]
    }

    /// Add to Favorites, or Remove from Favorites for a favorite (ADR 0131).
    private static func favoriteCommand(_ folder: FileItem, _ actions: ItemActions) -> ItemCommand {
        actions.isFavorite(folder)
            ? ItemCommand(
                title: String(localized: "Remove from Favorites"), symbol: "star.slash",
                perform: { actions.removeFavorite(folder) })
            : ItemCommand(
                title: String(localized: "Add to Favorites"), symbol: "star",
                perform: { actions.addFavorite(folder) })
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
