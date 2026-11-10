import Foundation
import Observation
import TreewiseCore

/// The state of one browser window: its panes and tabs, what each tab shows,
/// the sort order and the sidebar. Every action that names a pane also gives
/// that pane the focus, as clicking into it does.
@MainActor
@Observable
public final class BrowserState {
    /// The window's panes and tabs.
    public internal(set) var layout: PaneLayout
    /// How every list in the window is sorted.
    public private(set) var sort = ItemSort()
    /// The folder a new tab opens at.
    public let homeFolder: FileItem.ID
    /// The sidebar's Favorites.
    public internal(set) var favorites: [FileItem] = []
    /// The sidebar's Locations.
    public internal(set) var locations: [FileItem] = []
    /// What each tab shows.
    var contents: [TabModel.ID: TabContent] = [:]
    /// The items cut or copied, waiting to be pasted, on the clipboard this
    /// window shares with the others.
    public internal(set) var clipboard: ClipboardModel? {
        get { sharedClipboard.contents }
        set { sharedClipboard.contents = newValue }
    }
    /// Why the last operation failed, for the window to show; `nil` after a success.
    public internal(set) var failure: FileSystemError?
    /// How far the running transfer is, or `nil` when none runs.
    public internal(set) var progress: OperationProgress?
    /// Whether the running transfer is paused.
    public internal(set) var isPaused = false
    /// Whether the window shows folders as a list or as icons (ADR 0025).
    public var viewMode = ViewMode.list
    /// An item Treewise just made or renamed, which the list should bring into
    /// view; the list sets it back to `nil` when it does.
    public var revealRequest: FileItem.ID?
    /// An item the list should start renaming, such as a new folder; the
    /// list sets it back to `nil` when it starts.
    public var renameRequest: FileItem.ID?
    /// Whether the rename `renameRequest` asks for opens the proposals at once, as Rename
    /// with Suggestions does (ADR 0066); the list sets it back when it starts.
    public var renameSuggests = false

    /// The settings the window follows, such as showing hidden items.
    public let settings: BrowserSettings
    /// The licences of paid add-ons, which the app sets; without it, reviews ask with none
    /// (ADR 0071).
    @ObservationIgnored public var licences: LicenceKeeper?
    @ObservationIgnored private let sharedClipboard: SharedClipboard
    @ObservationIgnored let fileSystem: any FileSystemProviding
    /// The provider's operations, when it can change files.
    @ObservationIgnored let operations: (any FileOperating)?
    /// The provider's archive engine, when it has one (ADR 0074).
    @ObservationIgnored let archives: (any ArchiveOperating)?
    @ObservationIgnored let watcher: any FolderWatching
    @ObservationIgnored private let kinds: KindFormatter
    @ObservationIgnored var watches: [TabModel.ID: Watch] = [:]
    /// The number of each tab's latest reading; only that reading may show.
    @ObservationIgnored var latestLoads: [TabModel.ID: Int] = [:]
    /// The archives a tab shows, whose listing and copies are kept (ADR 0076).
    @ObservationIgnored var shownArchives: Set<FileItem.ID> = []
    /// The watch on This Mac, which keeps the Locations current (ADR 0044).
    @ObservationIgnored var locationsWatch: Task<Void, Never>?
    /// The transfer that runs, which `cancelOperation()` stops.
    @ObservationIgnored var runningTransfer: Task<OperationResult?, Never>?
    /// Pauses, resumes and stops the running transfer (ADR 0026).
    @ObservationIgnored var runningControl: TransferControl?

    /// Creates a window with one tab showing `startFolder`; `start()` loads it.
    /// New tabs open at `homeFolder`, which is the start folder unless given.
    /// Windows that share `clipboard` paste each other's cut and copied items.
    public init(
        fileSystem: any FileSystemProviding, watcher: any FolderWatching,
        startFolder: FileItem.ID, homeFolder: FileItem.ID? = nil,
        settings: BrowserSettings = BrowserSettings(store: MemorySettingsStore()),
        clipboard: SharedClipboard = SharedClipboard(), locale: Locale = .current
    ) {
        sharedClipboard = clipboard
        self.homeFolder = homeFolder ?? startFolder
        self.settings = settings
        self.fileSystem = fileSystem
        operations = fileSystem as? any FileOperating
        archives = fileSystem as? any ArchiveOperating
        self.watcher = watcher
        kinds = KindFormatter(locale: locale)
        layout = PaneLayout(at: startFolder)
    }

    /// Replaces the window's panes, tabs, sort order and view with restored
    /// ones (ADR 0024), before `start()` loads them.
    public func restore(_ layout: PaneLayout, sort: ItemSort, viewMode: ViewMode) {
        self.layout = layout
        self.sort = sort
        self.viewMode = viewMode
    }

    /// The window's panes, tabs, sort order and view, for the next launch (ADR 0024).
    public var snapshot: WindowSnapshot {
        WindowSnapshot(layout: layout, sort: sort, viewMode: viewMode)
    }

    /// Loads the sidebar and the folders the panes show.
    public func start() async {
        await reloadFavorites()
        locations = (try? await fileSystem.locations()) ?? []
        watchLocations()
        for pane in layout.panes {
            await load(pane.activeTabID)
        }
    }

    /// What a tab shows.
    public func content(of tab: TabModel.ID) -> TabContent {
        contents[tab] ?? TabContent()
    }

    /// A tab's items as the list shows them: filtered by its search text and sorted.
    public func visibleItems(of tab: TabModel.ID) -> [FileItem] {
        let content = content(of: tab)
        let shown =
            settings.showsHiddenFiles ? content.items : content.items.filter { !$0.isHidden }
        let matching =
            content.query.isEmpty
            ? shown
            : shown.filter { $0.name.localizedCaseInsensitiveContains(content.query) }
        return sort.sorted(matching, kinds: kinds)
    }

    /// The containers inside a folder, by name, for the sidebar tree, with
    /// each archive as the item of its top level (ADR 0076); empty when the
    /// folder cannot be read.
    public func subfolders(of folder: FileItem.ID) async -> [FileItem] {
        let items = (try? await fileSystem.contents(of: folder)) ?? []
        let folders = items.filter { settings.showsHiddenFiles || !$0.isHidden }
            .compactMap { item -> FileItem? in
                if item.isContainer { return item }
                return placeToOpen(for: item).flatMap(ArchivePath.init)
                    .map(ArchiveTree.topLevelItem)
            }
        return ItemSort().sorted(folders, kinds: kinds)
    }

    /// Sorts by a column; the same column again flips the direction.
    public func sort(by column: SortColumn) {
        sort = sort.selecting(column)
    }

    /// Sorts by a column in a direction, as the command bar's Sort menu chooses.
    public func sort(by column: SortColumn, ascending: Bool) {
        sort = ItemSort(column: column, ascending: ascending)
    }

    /// Selects an item in a tab: alone, or toggled into the selection when extending.
    public func select(_ id: FileItem.ID, in tab: TabModel.ID, extending: Bool) {
        var content = content(of: tab)
        if !extending {
            content.selection = [id]
        } else if content.selection.contains(id) {
            content.selection.remove(id)
        } else {
            content.selection.insert(id)
        }
        contents[tab] = content
    }

    /// Replaces a tab's selection, keeping only items the tab shows.
    public func setSelection(_ ids: Set<FileItem.ID>, in tab: TabModel.ID) {
        let shown = Set(content(of: tab).items.map(\.id))
        contents[tab, default: TabContent()].selection = ids.intersection(shown)
    }

    /// Sets the search text of a tab.
    public func setQuery(_ query: String, in tab: TabModel.ID) {
        contents[tab, default: TabContent()].query = query
    }

    /// Whether the folder a pane's active tab shows has an enclosing folder.
    public func canGoUp(pane: Int) -> Bool {
        guard layout.panes.indices.contains(pane) else { return false }
        return !content(of: layout.panes[pane].activeTabID).ancestry.isEmpty
    }

    /// Reads an item, for example one dropped or pasted from another app.
    public func item(at id: FileItem.ID) async throws -> FileItem {
        try await fileSystem.item(at: id)
    }

    /// Forgets the last failure, once the window has shown it.
    public func clearFailure() {
        failure = nil
    }

    /// Gives a pane the focus.
    public func focusPane(_ pane: Int) {
        layout.focusPane(at: pane)
    }
}
