import AppKit
import TreewiseCore
import os

/// Offers once, at launch, to copy Treewise into Applications when it runs
/// from elsewhere, such as Downloads or the disk image (ADR 0034). The copy
/// starts and this one quits; the original stays, since a translocated or
/// disk-image copy cannot be changed, and the alert says it can go to the Trash.
@MainActor
enum ApplicationsMover {
    /// The defaults key that records "Don't ask again".
    private static let declinedKey = "declinedMoveToApplications"
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "install")

    private static var folders: ApplicationsMove.Folders {
        let user = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Applications")
        return ApplicationsMove.Folders(system: "/Applications", user: user.path)
    }

    /// Asks when this is an unconfined Release build outside Applications that
    /// the user has not told to stop asking.
    static func offerIfNeeded() {
        guard LaunchOptions.isUnconfinedRelease,
            ApplicationsMove.shouldOffer(
                appPath: Bundle.main.bundleURL.path, folders: folders,
                declined: UserDefaults.standard.bool(forKey: declinedKey))
        else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Move Treewise to Applications?")
        alert.informativeText = String(
            localized:
                "Treewise can keep itself up to date only from the Applications folder. Afterwards you can move this copy to the Trash."
        )
        alert.addButton(withTitle: String(localized: "Move to Applications"))
        alert.addButton(withTitle: String(localized: "Don't Move"))
        alert.showsSuppressionButton = true
        let answer = alert.runModal()
        if alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: declinedKey)
        }
        guard answer == .alertFirstButtonReturn else { return }
        do {
            try relaunch(from: copyIntoApplications())
        } catch {
            logger.error("Moving to Applications failed: \(error.localizedDescription)")
            NSAlert(error: error).runModal()
        }
    }

    /// Copies the running app into Applications, moving a Treewise already
    /// there to the Trash first.
    private static func copyIntoApplications() throws -> URL {
        let manager = FileManager.default
        let folder = URL(
            fileURLWithPath: ApplicationsMove.destinationFolder(
                folders, systemIsWritable: manager.isWritableFile(atPath: folders.system)))
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(Bundle.main.bundleURL.lastPathComponent)
        if manager.fileExists(atPath: target.path) {
            try manager.trashItem(at: target, resultingItemURL: nil)
        }
        try manager.copyItem(at: Bundle.main.bundleURL, to: target)
        return target
    }

    /// Starts the copy in Applications and quits this one once it runs.
    private static func relaunch(from app: URL) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: app, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    logger.error("Starting the moved copy failed: \(error.localizedDescription)")
                    NSAlert(error: error).runModal()
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }
}
