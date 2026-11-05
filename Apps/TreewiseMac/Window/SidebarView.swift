import SwiftUI
import TreewiseCore
import TreewiseUI

/// The sidebar: Favorites and the Locations tree. Choosing a row shows it in
/// the active pane.
struct SidebarView: View {
    @Environment(\.fileUndoManager) private var undoManager

    let browser: BrowserState

    var body: some View {
        SidebarOutlineView(
            favorites: browser.favorites,
            locations: browser.locations,
            currentFolder: browser.layout.focusedPane.activeTab.folder,
            showsHiddenFiles: browser.settings.showsHiddenFiles,
            loadSubfolders: { await browser.subfolders(of: $0) },
            select: { folder in
                Task {
                    await browser.navigate(pane: browser.layout.focusedPaneIndex, to: folder.id)
                    // A favorite whose folder is gone loses its row.
                    await browser.reloadFavorites()
                }
            },
            eject: { VolumeEjection.eject($0) },
            drop: DropRouting.action(for: browser, undoManager: undoManager),
            favoriteActions: favoriteActions
        )
        // Every window shows the same list, and folders can return while Treewise is away.
        .task(id: browser.settings.favoriteFolders) { await browser.reloadFavorites() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            Task { await browser.reloadFavorites() }
        }
    }

    private var favoriteActions: SidebarFavoriteActions {
        SidebarFavoriteActions(
            add: { folder, next in Task { await browser.addFavorite(folder, before: next) } },
            remove: { folder in Task { await browser.removeFavorite(folder) } },
            move: { folder, next in Task { await browser.moveFavorite(folder, before: next) } },
            restore: { Task { await browser.restoreDefaultFavorites() } },
            isFavorite: { browser.isFavorite($0) })
    }
}
