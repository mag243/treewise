import Foundation
import TreewiseCore

/// New Folder as the iPad asks it: the name first, then the folder (ADR 0130). The Mac
/// makes "untitled folder" and renames it in place (`newFolder(undoManager:locale:)`).
extension BrowserState {
    /// The name New Folder fills in for the focused pane's folder: "untitled folder",
    /// numbered when taken; `nil` where no folder can be added.
    public func proposedNewFolderName(locale: Locale = .current) async -> String? {
        guard canAddItems, let operations else { return nil }
        let folder = layout.focusedPane.activeTab.folder
        let names = (try? await operations.itemsByName(in: folder).keys).map(Array.init) ?? []
        return FolderNaming.newFolderName(among: names, locale: locale)
    }

    /// Makes a folder named `name` in the focused pane's folder, as one step for Undo, and
    /// selects it; a name that cannot be used sets `failure` and makes nothing.
    @discardableResult
    public func newFolder(named name: String, undoManager: UndoManager?) async -> FileItem? {
        guard canAddItems else { return nil }
        let folder = layout.focusedPane.activeTab.folder
        if let place = ArchivePath(folder) {
            return await newFolderInArchive(at: place, named: name, undoManager: undoManager)
        }
        let result = await perform(name: Self.actionName("New Folder"), undoManager: undoManager) {
            try await $0.createFolder(named: name, in: folder)
        }
        selectInFocusedTab(result?.items ?? [])
        return result?.items.first
    }
}
