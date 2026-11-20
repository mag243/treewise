import Foundation
import Synchronization
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import UIKit

/// Syncing on the iPad (ADR 0144): through the locations that are a cloud drive's root,
/// less those the user left out; the devices' folders watched while the app is in front,
/// and read again when it comes to the front and before a screen of synced settings opens.
@MainActor
enum IPadSync {
    /// A location and whether it can take part.
    struct Drive: Identifiable, Hashable {
        let folder: URL
        let name: String
        /// Whether it is a drive's root; a folder inside one cannot reach the root's
        /// `.treewise` folder.
        let isRoot: Bool
        var id: URL { folder }
    }

    private(set) static var controller: SyncController?
    /// The drives where the user started syncing from here, for the sync, off the main actor.
    private static let startedHere = StartedDrives()
    /// The cloud locations, root or not, for Settings' General tab.
    private(set) static var cloudLocations: [Drive] = []
    private static var presenters: [FolderPresenter] = []

    /// Starts syncing through `folders`' drive roots with `settings`, or changes the drives.
    static func start(settings: BrowserSettings, folders: [URL], names: [URL: String]) async {
        cloudLocations = folders.filter(LocalFileSystem.Locations.systemIsInCloud).map {
            Drive(folder: $0, name: names[$0] ?? $0.lastPathComponent, isRoot: isDriveRoot($0))
        }
        startedHere.set(settings.syncStartedHere)
        let controller = controller ?? make(settings: settings)
        self.controller = controller
        await controller.start(drives: drives(leavingOut: settings.syncLeavesOut))
        watch()
    }

    /// The roots that take part, less `leftOut`.
    static func drives(leavingOut leftOut: Set<String>) -> [URL] {
        cloudLocations.filter { $0.isRoot && !leftOut.contains($0.folder.path) }.map(\.folder)
    }

    /// Leaves the drive at `folder` out, or lets it take part again.
    static func setTakesPart(_ takesPart: Bool, _ folder: URL, settings: BrowserSettings) async {
        if takesPart {
            settings.syncLeavesOut.remove(folder.path)
        } else {
            settings.syncLeavesOut.insert(folder.path)
        }
        await controller?.start(drives: drives(leavingOut: settings.syncLeavesOut))
        watch()
    }

    /// Starts syncing in the drive at `folder` from here, making the visible sync folder
    /// there (ADR 0144).
    static func startHere(_ folder: URL, settings: BrowserSettings) async {
        let path = folder.standardizedFileURL.path
        settings.syncStartedHere.insert(path)
        startedHere.set(settings.syncStartedHere)
        await refresh()
        // Made once: when the folder is gone later, as a Mac hid it, the iPad waits for
        // the hidden one rather than making the visible one again.
        if problem(of: folder) == nil {
            settings.syncStartedHere.remove(path)
            startedHere.set(settings.syncStartedHere)
        }
    }

    /// Why the drive at `folder` does not sync, if it does not.
    static func problem(of folder: URL) -> SyncFolder.Problem? {
        controller?.driveProblems[folder.standardizedFileURL.path]
    }

    /// Reads the drives again and the templates after, as a template may have come.
    static func refresh() async {
        await controller?.refresh()
        await NameServices.templateList.load()
    }

    /// Stops watching while the app is in the background, as iOS asks of file presenters.
    static func pause() {
        for presenter in presenters { NSFileCoordinator.removeFilePresenter(presenter) }
        presenters = []
    }

    /// Watches again once the app is in front, and reads what came meanwhile.
    static func resume() async {
        watch()
        await refresh()
    }

    private static func watch() {
        pause()
        presenters = (controller?.drives ?? []).map { root in
            SyncFolder(driveRoot: root, device: SyncDevice(id: "", name: "")).presenter {
                Task { @MainActor in await refresh() }
            }
        }
        for presenter in presenters { NSFileCoordinator.addFilePresenter(presenter) }
    }

    private static func make(settings: BrowserSettings) -> SyncController {
        let directory = NameServices.settingsDirectory
        return SyncController(
            settings: settings,
            session: SyncSession(
                sync: SettingsSync(
                    device: SyncDevice.load(from: directory, name: UIDevice.current.name),
                    making: { [startedHere] root in
                        startedHere.contains(root.standardizedFileURL.path) ? .visible : .none
                    }),
                folders: NameServices.folderSettings, templates: NameServices.templates),
            conflicts: SyncConflictStore(directory: directory))
    }

    /// Whether `folder` is a cloud drive's root: the document picker gave exactly it, so
    /// the folder above cannot be listed.
    private static func isDriveRoot(_ folder: URL) -> Bool {
        let parent = folder.deletingLastPathComponent()
        return (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) == nil
    }
}

/// The drives where the user started syncing from this device, read by the sync off the
/// main actor.
private final class StartedDrives: Sendable {
    private let paths = Mutex<Set<String>>([])

    func set(_ new: Set<String>) {
        paths.withLock { $0 = new }
    }

    func contains(_ path: String) -> Bool {
        paths.withLock { $0.contains(path) }
    }
}
