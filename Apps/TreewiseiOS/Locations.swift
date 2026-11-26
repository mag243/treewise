import Foundation
import Observation
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import os

/// The folders the user added and every window's browser over them (ADR 0045, 0134).
/// A browser's provider is confined to the added folders, so adding or removing one
/// makes every window a new browser, at the folder the old one showed when it is still
/// reachable. The clipboard and undo are shared by every window.
@MainActor
@Observable
final class Locations {
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "locations")
    /// The file in Application Support that keeps the bookmarks.
    private static let bookmarksFile = "Treewise/Locations.json"

    /// The windows shown, by the identity of their `WindowRequest`; a view observes its
    /// window itself, which it may ask for while it draws.
    @ObservationIgnored private var windows: [UUID: BrowserWindow] = [:]
    /// Whether the saved folders were resolved, so the empty state is not
    /// shown for a moment at launch.
    private(set) var isLoaded = false
    /// The added folders that could not be reached at launch, such as one on a drive
    /// that is not attached, to connect again (ADR 0111).
    private(set) var unavailable: [Bookmark] = []
    /// The app's one undo history (ADR 0047).
    let undo = SharedUndo()

    let settings: BrowserSettings
    @ObservationIgnored private let added: AddedFolders
    /// A UI test's run, whose bookmarks and settings are its own (ADR 0114).
    @ObservationIgnored private let testRun: TestRun?
    /// Reads the added folders, to find the items a drag carries.
    @ObservationIgnored private var reader: LocalFileSystem?
    @ObservationIgnored private let clipboard = SharedClipboard()
    /// The added folders confined, for a window's browser; `nil` until they are read.
    @ObservationIgnored private var confined: LocalFileSystem.Locations?
    /// The first added folder, where a window opens that has nowhere else to go.
    @ObservationIgnored private var firstFolder: URL?
    /// Reads the saved folders once, for whichever window asks first.
    @ObservationIgnored private var loading: Task<Void, Never>?
    /// The window the user was last in, whose folder the next launch starts at.
    @ObservationIgnored private var lastActive: UUID?

    init(testRun: TestRun? = .current) {
        let support =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        let file = testRun?.bookmarksFile ?? support.appendingPathComponent(Self.bookmarksFile)
        self.testRun = testRun
        settings = BrowserSettings(store: testRun?.defaults ?? UserDefaults.standard)
        added = AddedFolders(store: BookmarkStore(storage: FileBookmarkStorage(file: file)))
    }

    /// The window that `request` presents; made the first time it is asked for.
    func window(for request: WindowRequest) -> BrowserWindow {
        if let window = windows[request.id] { return window }
        let window = BrowserWindow(opening: request.opening)
        windows[request.id] = window
        return window
    }

    /// Resolves the saved folders, once, and gives the window of `request` its browser.
    func open(_ request: WindowRequest) async {
        if loading == nil {
            loading = Task { await load() }
        }
        await loading?.value
        let window = window(for: request)
        guard window.browser == nil else { return }
        await rebuild(window)
    }

    /// Forgets a window the user closed; its browser stops watching.
    func close(_ request: WindowRequest) {
        windows.removeValue(forKey: request.id)?.browser?.stop()
        if lastActive == request.id { lastActive = nil }
    }

    /// Notes the window the user is in, whose folder the next launch starts at.
    func activate(_ request: WindowRequest) {
        lastActive = request.id
    }

    /// Stops watching every window's folders while the app is in the background
    /// (ADR 0120).
    func pauseWatching() {
        for window in windows.values { window.browser?.pauseWatching() }
    }

    /// Reads every window's folders again and watches them again (ADR 0120).
    func resumeWatching() async {
        for window in windows.values { await window.browser?.resumeWatching() }
    }

    private func load() async {
        try? testRun?.removeAskedFolder()
        await added.load()
        await addFixtureIfEmpty()
        unavailable = await added.unavailable()
        await readFolders()
        isLoaded = true
    }

    /// Puts a folder the user picked in the place of one that could not be reached,
    /// and shows it.
    func reconnect(_ bookmark: Bookmark, to url: URL, in window: BrowserWindow) async {
        do {
            try await added.reconnect(bookmark, to: url)
        } catch {
            Self.logger.error("Folder not reconnected: \(error.localizedDescription)")
            window.addFailure = error.localizedDescription
            return
        }
        unavailable = await added.unavailable()
        await rebuildAll()
        await window.browser?.navigate(pane: 0, to: FileItem.ID(url.standardizedFileURL.path))
    }

    /// Forgets a folder that could not be reached.
    func forget(_ bookmark: Bookmark) async {
        await added.forget(bookmark)
        unavailable = await added.unavailable()
    }

    /// Adds a folder the user picked and shows it.
    func add(_ url: URL, in window: BrowserWindow) async {
        do {
            try await added.add(url)
        } catch {
            Self.logger.error("Folder not added: \(error.localizedDescription)")
            window.addFailure = error.localizedDescription
            return
        }
        await rebuildAll()
        await window.browser?.navigate(pane: 0, to: FileItem.ID(url.standardizedFileURL.path))
        if LocationLabel.isMachineMade(url.lastPathComponent) {
            window.naming = LocationNaming(folder: url, label: "")
        }
    }

    /// Asks in `window` for a location's name, filled with the name the user gave it.
    func rename(_ location: FileItem, in window: BrowserWindow) async {
        let url = URL(fileURLWithPath: location.id.rawValue)
        window.naming = LocationNaming(
            folder: url, label: await added.bookmark(of: url)?.label ?? "")
    }

    /// Gives a location the name typed; an empty name gives the folder its own name
    /// back (ADR 0119).
    func name(_ naming: LocationNaming) async {
        await added.setLabel(LocationLabel.cleaned(naming.label), of: naming.folder)
        await rebuildAll()
    }

    /// Forgets an added folder; every window showing it moves away from it.
    func remove(_ location: FileItem) async {
        await added.remove(URL(fileURLWithPath: location.id.rawValue))
        await rebuildAll()
    }

    /// Adds a UI test's fixture folders, its favorites and its recent targets, when its run
    /// has no locations yet (ADR 0114).
    private func addFixtureIfEmpty() async {
        guard let testRun, await added.folders().isEmpty, await added.unavailable().isEmpty,
            let folders = try? testRun.fixtureFolders()
        else { return }
        for folder in folders { try? await added.add(folder) }
        let favorites = testRun.fixtureFavorites()
        if !favorites.isEmpty {
            settings.favoriteFolders = favorites.map { FileItem.ID($0.standardizedFileURL.path) }
        }
        settings.recentTargets = RecentTargets(
            folders: testRun.fixtureRecentTargets().map {
                FileItem.ID($0.standardizedFileURL.path)
            })
    }

    /// The item at `id` in the added folders as it is now, if it is in them.
    func item(at id: FileItem.ID) -> FileItem? {
        try? reader?.currentItem(at: id)
    }

    /// Keeps the folder shown and the sort order of the window the user was last in, for
    /// the next launch and for a new window.
    func save() {
        let window = lastActive.flatMap { windows[$0] } ?? windows.values.first
        guard let browser = window?.browser else { return }
        settings.lastSession = SessionSnapshot(window: browser.snapshot)
    }

    /// Reads the added folders and confines a provider to them.
    private func readFolders() async {
        let folders = await added.folders()
        var labels: [URL: String] = [:]
        for folder in folders {
            labels[folder] =
                await added.bookmark(of: folder)?.label ?? Self.defaultLabel(of: folder)
        }
        let locations = LocalFileSystem.Locations.added(
            folders, home: URL.homeDirectory, labels: labels)
        confined = locations
        firstFolder = folders.first
        reader = LocalFileSystem(locations: locations)
        await IPadSync.start(settings: settings, folders: folders, names: labels)
    }

    /// Reads the added folders again and makes every window a new browser.
    private func rebuildAll() async {
        await readFolders()
        for window in windows.values { await rebuild(window) }
    }

    /// Makes `window` a browser over the added folders, at the folder its browser shows,
    /// or the one it opens at, or the last window's, when that is still reachable, else at
    /// the first added folder.
    private func rebuild(_ window: BrowserWindow) async {
        let previous = window.browser
        previous?.stop()
        guard let confined, let first = firstFolder, let reader else {
            window.browser = nil
            return
        }
        let isUsable = { (id: FileItem.ID) in (try? reader.currentItem(at: id)) != nil }
        let snapshot =
            previous?.snapshot ?? window.opening
            ?? settings.lastSession?.groups.first.map {
                $0.tabs[$0.selectedTab]
            }
        let state = BrowserState(
            fileSystem: FileOperationRunner(
                locations: confined, folderSettings: NameServices.folderSettings),
            watcher: DirectoryWatcher(), startFolder: FileItem.ID(first.standardizedFileURL.path),
            settings: settings, clipboard: clipboard)
        if let restored = snapshot?.restored(isUsable: isUsable) {
            state.restore(restored)
        }
        window.opening = nil
        window.browser = state
        await state.start()
    }

    /// The name of a location the user did not name, where its folder's own name says
    /// nothing (ADR 0119): On My iPad or On My iPhone, and Cloud for a folder named by a
    /// UUID.
    private static func defaultLabel(of folder: URL) -> String? {
        if LocalFileSystem.Locations.isOnMyDeviceFolder(folder) {
            return DeviceKind.isPhone
                ? String(
                    localized: "On My iPhone", comment: "The location of the iPhone's own files")
                : String(localized: "On My iPad", comment: "The location of the iPad's own files")
        }
        if LocationLabel.isMachineMade(folder.lastPathComponent) {
            return String(localized: "Cloud", comment: "A cloud location the user did not name")
        }
        return nil
    }
}
