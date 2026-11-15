import AppKit
import Sparkle

/// Sparkle's updater (ADR 0032). It starts only in an unconfined Release
/// build (`LaunchOptions.isUnconfinedRelease`), so a development build never
/// offers to replace itself with a release. The target of "Check for
/// Updates…" in the app menu, which it enables when it can check (ADR 0081),
/// and what the toggle in Settings › General changes.
@MainActor
final class AppUpdater: NSObject, NSMenuItemValidation {
    /// Whether Sparkle looks for a new version once a day by itself; it reads and writes
    /// Sparkle's own setting.
    var checksAutomatically: Bool {
        get { isRunning && controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    /// Whether the updater started; Settings disables its toggle when not.
    let isRunning: Bool

    private let controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

    override init() {
        isRunning = LaunchOptions.isUnconfinedRelease
        super.init()
        guard isRunning else { return }
        controller.startUpdater()
    }

    /// Looks for a new version now and shows what it finds.
    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    /// Whether "Check for Updates…" can run now: the updater started and is not busy.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        isRunning && controller.updater.canCheckForUpdates
    }
}
