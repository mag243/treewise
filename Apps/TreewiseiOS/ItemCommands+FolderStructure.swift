import Foundation
import TreewiseCore

/// Folder Structure ▸ in a folder's menu, as on the Mac (ADR 0091, ADR 0099, ADR 0142): New
/// Folders from Template ▸ with the saved templates, Save as Template…, Copy Structure and,
/// once one is copied, Paste Structure….
extension ItemCommands {
    /// The submenu for a folder the menu is on.
    static func folderStructureCommands(_ item: FileItem, _ actions: ItemActions)
        -> [[ItemCommand]]
    {
        guard item.kind == .folder, !item.id.isInsideArchive,
            let structure = actions.folderStructure
        else { return [] }
        let folder = item.id
        var commands = [
            newFolders(in: folder, isEnabled: true, structure, actions),
            ItemCommand(
                title: String(localized: "Save as Template…"), symbol: "square.and.arrow.down",
                perform: { structure(.save(folder)) }),
            ItemCommand(
                title: String(localized: "Copy Structure"), symbol: "doc.on.doc",
                perform: { structure(.copy(folder)) }),
        ]
        commands += paste(in: folder, isEnabled: true, structure, actions)
        return [[submenu(commands)]]
    }

    /// The submenu for the folder shown, from a long press on empty space: New Folders from
    /// Template ▸ and Paste Structure…, as the Mac's.
    static func shownFolderStructureCommands(_ actions: ItemActions) -> [[ItemCommand]] {
        guard let structure = actions.folderStructure, let folder = actions.shownFolder else {
            return []
        }
        let isEnabled = actions.canAddItems
        let commands =
            [newFolders(in: folder, isEnabled: isEnabled, structure, actions)]
            + paste(in: folder, isEnabled: isEnabled, structure, actions)
        return [[submenu(commands)]]
    }

    private static func submenu(_ commands: [ItemCommand]) -> ItemCommand {
        .submenu(
            String(localized: "Folder Structure"), symbol: "folder.badge.gearshape", commands)
    }

    /// New Folders from Template ▸, with each saved template, or No Templates greyed.
    private static func newFolders(
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
            String(localized: "New Folders from Template"), symbol: "folder.badge.plus",
            templates)
    }

    /// Paste Structure…, only while a structure is copied.
    private static func paste(
        in folder: FileItem.ID, isEnabled: Bool,
        _ structure: @escaping (FolderStructureRequest) -> Void, _ actions: ItemActions
    ) -> [ItemCommand] {
        guard let copied = actions.copiedStructure else { return [] }
        return [
            ItemCommand(
                title: String(localized: "Paste Structure…"), symbol: "doc.on.clipboard",
                isEnabled: isEnabled, perform: { structure(.paste(copied, in: folder)) })
        ]
    }
}
