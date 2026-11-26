import AppKit
import TreewiseCore
import TreewiseUI

/// The sidebar: Favorites and the Locations tree. Choosing a row shows it in
/// the active pane.
@MainActor
final class SidebarController: NSViewController {
    private let browser: BrowserState
    private let outline = SidebarCoordinator()
    /// The favorites setting whose folders the sidebar last read; `.none`
    /// until it read them once.
    private var readFavorites: [FileItem.ID]??
    private var becameActive: (any NSObjectProtocol)?

    init(browser: BrowserState) {
        self.browser = browser
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = outline.makeScrollView()
        Observing.follow(self) { $0.update() }
        followFolderChanges()
    }

    /// Reads the tree's rows of the folders any window's operations changed (ADR 0112).
    private func followFolderChanges() {
        let changes = browser.folderChanges.changes()
        Task { [weak self] in
            for await folders in changes {
                guard let self else { return }
                outline.readAgain(changed: folders)
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // Folders can return while Treewise is away.
        becameActive = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadFavorites() }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        becameActive.map(NotificationCenter.default.removeObserver)
        becameActive = nil
    }

    private func update() {
        // Every window shows the same list.
        let favorites = browser.settings.favoriteFolders
        if readFavorites != .some(favorites) {
            readFavorites = .some(favorites)
            reloadFavorites()
        }
        outline.update(with: content)
    }

    private func reloadFavorites() {
        let browser = browser
        Task { await browser.reloadFavorites() }
    }

    private var content: SidebarContent {
        let browser = browser
        let undoManager = SharedUndo.manager
        return SidebarContent(
            favorites: browser.favorites,
            locations: browser.locations,
            currentFolder: browser.layout.focusedPane.activeTab.folder,
            pathToReveal: browser.settings.expandsSidebarToOpenFolder ? browser.treePath : nil,
            showsHiddenFiles: browser.settings.showsHiddenFiles,
            loadSubfolders: { await browser.subfolders(of: $0) },
            subfolderPresence: { await browser.subfolderPresence(in: $0) },
            changes: { browser.changes(of: $0) },
            shownListing: shownListing,
            select: { folder in
                Task {
                    await browser.navigate(pane: browser.layout.focusedPaneIndex, to: folder.id)
                    // A favorite whose folder is gone loses its row.
                    await browser.reloadFavorites()
                }
            },
            eject: { VolumeEjection.eject($0) },
            marksRepository: { browser.gitStatus?.marksRepository($0) ?? false },
            showsGitStatus: browser.settings.showsGitStatus,
            gitState: { browser.gitStatus?.state(ofFolder: $0) },
            followRepository: { await browser.gitStatus?.follow($0) },
            gitRevision: browser.gitStatus?.revision ?? 0,
            drop: DropRouting.action(for: browser, undoManager: undoManager),
            favoriteActions: favoriteActions)
    }

    private var shownListing: SidebarShownListing {
        let pane = browser.layout.focusedPane
        return SidebarShownListing(
            folder: pane.activeTab.folder,
            items: browser.content(of: pane.activeTabID).items.map(\.id))
    }

    private var favoriteActions: SidebarFavoriteActions {
        let browser = browser
        return SidebarFavoriteActions(
            add: { folder, next in Task { await browser.addFavorite(folder, before: next) } },
            remove: { folder in Task { await browser.removeFavorite(folder) } },
            move: { folder, next in Task { await browser.moveFavorite(folder, before: next) } },
            restore: { Task { await browser.restoreDefaultFavorites() } },
            isFavorite: { browser.isFavorite($0) })
    }
}
