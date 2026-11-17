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
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "locations")
    /// The file in Application Support that keeps the bookmarks.
    private static let bookmarksFile = "Treewise/Locations.json"

    /// The browser over the added folders; `nil` while none is added.
    private(set) var browser: BrowserState?
    /// Whether the saved folders were resolved, so the empty state is not
    /// shown for a moment at launch.
    private(set) var isLoaded = false
    /// Why the last folder could not be added, for an alert.
    var addFailure: String?
    /// The added folders that could not be reached at launch, such as one on a drive
    /// that is not attached, to connect again (ADR 0111).
    private(set) var unavailable: [Bookmark] = []
    /// Asks what to do with a name taken, for every operation of the window.
    let conflicts = ConflictQuestions()
    /// The app's one undo history (ADR 0047).
    let undo = SharedUndo()
    /// Why the last drop was refused as it landed, for an alert (ADR 0047, amended).
    var dropRefusal: String?

    /// The location the naming question names: one just added whose folder's name is
    /// a UUID, or one the user renames (ADR 0119).
    var naming: LocationNaming?

    let settings: BrowserSettings
    @ObservationIgnored private let added: AddedFolders
    /// A UI test's run, whose bookmarks and settings are its own (ADR 0114).
    @ObservationIgnored private let testRun: TestRun?
    /// Reads the added folders, to find the items a drag carries.
    @ObservationIgnored private var reader: LocalFileSystem?
    @ObservationIgnored private let watcher = DirectoryWatcher()
    @ObservationIgnored private let clipboard = SharedClipboard()

    init(testRun: TestRun? = .current) {
        let support =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        let file = testRun?.bookmarksFile ?? support.appendingPathComponent(Self.bookmarksFile)
        self.testRun = testRun
        settings = BrowserSettings(store: testRun?.defaults ?? UserDefaults.standard)
        added = AddedFolders(store: BookmarkStore(storage: FileBookmarkStorage(file: file)))
    }

    /// Resolves the saved folders and opens the browser where the last
    /// launch left it.
    func start() async {
        try? testRun?.removeAskedFolder()
        await added.load()
        await addFixtureIfEmpty()
        unavailable = await added.unavailable()
        await rebuild(restoring: settings.lastSession)
        isLoaded = true
    }

    /// Puts a folder the user picked in the place of one that could not be reached,
    /// and shows it.
    func reconnect(_ bookmark: Bookmark, to url: URL) async {
        do {
            try await added.reconnect(bookmark, to: url)
        } catch {
            Self.logger.error("Folder not reconnected: \(error.localizedDescription)")
            addFailure = error.localizedDescription
            return
        }
        unavailable = await added.unavailable()
        await rebuild(restoring: nil)
        await browser?.navigate(pane: 0, to: FileItem.ID(url.standardizedFileURL.path))
    }

    /// Forgets a folder that could not be reached.
    func forget(_ bookmark: Bookmark) async {
        await added.forget(bookmark)
        unavailable = await added.unavailable()
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
        if LocationLabel.isMachineMade(url.lastPathComponent) {
            naming = LocationNaming(folder: url, label: "")
        }
    }

    /// Asks for a location's name, filled with the name the user gave it.
    func rename(_ location: FileItem) async {
        let url = URL(fileURLWithPath: location.id.rawValue)
        naming = LocationNaming(folder: url, label: await added.bookmark(of: url)?.label ?? "")
    }

    /// Gives a location the name typed; an empty name gives the folder its own name
    /// back (ADR 0119).
    func name(_ naming: LocationNaming) async {
        await added.setLabel(LocationLabel.cleaned(naming.label), of: naming.folder)
        await rebuild(restoring: nil)
    }

    /// Forgets an added folder; the browser moves away from it.
    func remove(_ location: FileItem) async {
        await added.remove(URL(fileURLWithPath: location.id.rawValue))
        await rebuild(restoring: nil)
    }

    /// Adds a UI test's fixture folders when its run has no locations yet (ADR 0114).
    private func addFixtureIfEmpty() async {
        guard let testRun, await added.folders().isEmpty, await added.unavailable().isEmpty,
            let folders = try? testRun.fixtureFolders()
        else { return }
        for folder in folders { try? await added.add(folder) }
    }

    /// The item at `id` in the added folders as it is now, if it is in them.
    func item(at id: FileItem.ID) -> FileItem? {
        try? reader?.currentItem(at: id)
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
        var labels: [URL: String] = [:]
        for folder in folders {
            labels[folder] =
                await added.bookmark(of: folder)?.label ?? Self.defaultLabel(of: folder)
        }
        let confined = LocalFileSystem.Locations.added(
            folders, home: URL.homeDirectory, labels: labels)
        let fileSystem = LocalFileSystem(locations: confined)
        reader = fileSystem
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

    /// The name of a location the user did not name, where its folder's own name says
    /// nothing (ADR 0119): On My iPad, and Cloud for a folder named by a UUID.
    private static func defaultLabel(of folder: URL) -> String? {
        if LocalFileSystem.Locations.isOnMyDeviceFolder(folder) {
            return String(localized: "On My iPad", comment: "The location of the iPad's own files")
        }
        if LocationLabel.isMachineMade(folder.lastPathComponent) {
            return String(localized: "Cloud", comment: "A cloud location the user did not name")
        }
        return nil
    }
}
