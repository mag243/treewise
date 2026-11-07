import Foundation
import TreewiseFileSystem

/// Drops, about once a day, the settings of folders long unseen (ADR 0072). A background
/// activity, so macOS runs it when the Mac is idle and starting the app never waits for it.
@MainActor
enum FolderSettingsCleaner {
    private static let identifier = "me.m-domain.treewise.folder-settings-cleanup"
    /// How often the check runs, and how much later macOS may run it.
    private static let interval: TimeInterval = 24 * 60 * 60
    private static let tolerance: TimeInterval = 4 * 60 * 60

    private static let scheduler: NSBackgroundActivityScheduler = {
        let scheduler = NSBackgroundActivityScheduler(identifier: identifier)
        scheduler.repeats = true
        scheduler.interval = interval
        scheduler.tolerance = tolerance
        scheduler.qualityOfService = .background
        return scheduler
    }()

    /// Starts the daily check, with the store the overview uses.
    static func start(with store: FolderSettingsStore) {
        scheduler.schedule { completion in
            Task.detached(priority: .background) {
                await store.dropSettingsOfUnseenFolders(now: Date())
                completion(.finished)
            }
        }
    }
}
