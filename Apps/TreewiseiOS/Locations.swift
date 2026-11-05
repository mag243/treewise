import Foundation
import Observation
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import os

/// The folders the user added and the browser over them (ADR 0045). The
/// browser's provider is confined to the added folders, so adding or removing
/// one makes a new browser, at the folder the old one showed when it is still
/// reachable.
@MainActor
@Observable
final class Locations {
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "locations")
    /// The file in Application Support that keeps the bookmarks.
    private static let bookmarksFile = "Treewise/Locations.json"

    /// The browser over the added folders; `nil` while none is added.
    private(set) var browser: BrowserState?
    /// Whether the saved folders were resolved, so the empty state is not
    /// shown for a moment at launch.
    private(set) var isLoaded = false
    /// Why the last folder could not be added, for an alert.
    var addFailure: String?

    let settings = BrowserSettings(store: UserDefaults.standard)
    @ObservationIgnored private let added: AddedFolders
    @ObservationIgnored private let watcher = DirectoryWatcher()
    @ObservationIgnored private let clipboard = SharedClipboard()

    init() {
        let support =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        added = AddedFolders(
            store: BookmarkStore(
                storage: FileBookmarkStorage(
                    file: support.appendingPathComponent(Self.bookmarksFile))))
    }

    /// Resolves the saved folders and opens the browser where the last
    /// launch left it.
    func start() async {
        await added.load()
        await rebuild(restoring: settings.lastSession)
        isLoaded = true
    }

    /// Adds a folder the user picked and shows it.
    func add(_ url: URL) async {
        do {
            try await added.add(url)
        } catch {
            Self.logger.error("Folder not added: \(error.localizedDescription)")
            addFailure = error.localizedDescription
            return
        }
        await rebuild(restoring: nil)
        await browser?.navigate(pane: 0, to: FileItem.ID(url.standardizedFileURL.path))
    }

    /// Forgets an added folder; the browser moves away from it.
    func remove(_ location: FileItem) async {
        await added.remove(URL(fileURLWithPath: location.id.rawValue))
        await rebuild(restoring: nil)
    }

    /// Keeps the folder shown and the sort order for the next launch.
    func save() {
        guard let browser else { return }
        settings.lastSession = SessionSnapshot(window: browser.snapshot)
    }

    /// Makes a browser over the added folders, at the folder `session` or the
    /// current browser shows when it is still reachable, else at the first
    /// added folder.
    private func rebuild(restoring session: SessionSnapshot?) async {
        let folders = await added.folders()
        let confined = LocalFileSystem.Locations.added(folders, home: URL.homeDirectory)
        let fileSystem = LocalFileSystem(locations: confined)
        guard let first = folders.first else {
            browser = nil
            return
        }
        let isUsable = { (id: FileItem.ID) in (try? fileSystem.currentItem(at: id)) != nil }
        let previous = session ?? browser.map { SessionSnapshot(window: $0.snapshot) }
        let restored = previous?.restored(isUsable: isUsable).first.map {
            $0.tabs[$0.selectedTab]
        }
        let state = BrowserState(
            fileSystem: FileOperationRunner(locations: confined), watcher: watcher,
            startFolder: FileItem.ID(first.standardizedFileURL.path), settings: settings,
            clipboard: clipboard)
        if let restored {
            state.restore(restored.layout, sort: restored.sort, viewMode: restored.viewMode)
        }
        browser = state
        await state.start()
    }
}
