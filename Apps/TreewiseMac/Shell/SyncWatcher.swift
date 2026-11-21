import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// Starts syncing through the Mac's cloud drives and reads them again when another device's
/// change arrives or the app becomes active (ADR 0144).
@MainActor
enum SyncWatcher {
    private static var presenters: [FolderPresenter] = []
    /// The readings asked for, a burst of a provider's notices read as one more.
    private static let refreshes = CoalescedWork {
        await AppServices.sync.refresh()
        await FolderTemplatesService.templates.load()
    }

    /// Starts the sync over the cloud locations of the sidebar (ADR 0049).
    static func start() {
        Task {
            let locations =
                (try? await LocalFileSystem(locations: LaunchOptions.locations)
                    .locations()) ?? []
            let drives = locations.filter { $0.kind == .cloud }.map {
                URL(filePath: $0.id.rawValue)
            }
            await AppServices.sync.start(drives: drives)
            watch(drives)
        }
    }

    /// Reads the drives again, as before a screen that shows synced settings opens.
    /// The templates' list is read again too, as a template may have come from another
    /// device; New Folders from Template ▸, a menu, cannot wait for the drives.
    static func refresh() async {
        await refreshes.request()
    }

    private static func watch(_ drives: [URL]) {
        for presenter in presenters { NSFileCoordinator.removeFilePresenter(presenter) }
        presenters = drives.map { root in
            SyncFolder(driveRoot: root, device: SyncDevice(id: "", name: "")).presenter {
                Task { @MainActor in await refresh() }
            }
        }
        for presenter in presenters { NSFileCoordinator.addFilePresenter(presenter) }
    }
}
