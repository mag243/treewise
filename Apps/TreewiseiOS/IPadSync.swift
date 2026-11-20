import Foundation
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
    /// The cloud locations, root or not, for Settings' General tab.
    private(set) static var cloudLocations: [Drive] = []
    private static var presenters: [FolderPresenter] = []

    /// Starts syncing through `folders`' drive roots with `settings`, or changes the drives.
    static func start(settings: BrowserSettings, folders: [URL], names: [URL: String]) async {
        cloudLocations = folders.filter(LocalFileSystem.Locations.systemIsInCloud).map {
            Drive(folder: $0, name: names[$0] ?? $0.lastPathComponent, isRoot: isDriveRoot($0))
        }
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
                    device: SyncDevice.load(from: directory, name: UIDevice.current.name)),
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
