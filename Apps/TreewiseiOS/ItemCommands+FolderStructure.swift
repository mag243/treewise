import Foundation
import TreewiseCore

/// Folder Structure ▸ in a folder's menu, as on the Mac (ADR 0091, ADR 0142): New Folders
/// from Template ▸ with the saved templates, and Save as Template….
extension ItemCommands {
    /// The submenu for a folder the menu is on.
    static func folderStructureCommands(_ item: FileItem, _ actions: ItemActions)
        -> [[ItemCommand]]
    {
        guard item.kind == .folder, !item.id.isInsideArchive,
            let structure = actions.folderStructure
        else { return [] }
        return [[submenu(in: item.id, isEnabled: true, structure, actions)]]
    }

    /// The submenu for the folder shown, from a long press on empty space.
    static func shownFolderStructureCommands(_ actions: ItemActions) -> [[ItemCommand]] {
        guard let structure = actions.folderStructure, let folder = actions.shownFolder else {
            return []
        }
        return [[submenu(in: folder, isEnabled: actions.canAddItems, structure, actions)]]
    }

    private static func submenu(
        in folder: FileItem.ID, isEnabled: Bool,
        _ structure: @escaping (FolderStructureRequest) -> Void, _ actions: ItemActions
    ) -> ItemCommand {
        var templates = actions.templates.map { template in
            ItemCommand(
                title: template.name, symbol: "folder", isEnabled: isEnabled,
                perform: { structure(.make(template, in: folder)) })
        }
        if templates.isEmpty {
            templates = [
                ItemCommand(
                    title: String(localized: "No Templates"), symbol: "folder",
                    isEnabled: false, perform: {})
            ]
        }
        return .submenu(
            String(localized: "Folder Structure"), symbol: "folder.badge.gearshape",
            [
                .submenu(
                    String(localized: "New Folders from Template"),
                    symbol: "folder.badge.plus", templates),
                ItemCommand(
                    title: String(localized: "Save as Template…"),
                    symbol: "square.and.arrow.down",
                    perform: { structure(.save(folder)) }),
            ])
    }
}
