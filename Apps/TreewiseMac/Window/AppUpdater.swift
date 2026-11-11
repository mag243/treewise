import AppKit
import Combine
import Sparkle

/// Sparkle's updater (ADR 0032). It starts only in an unconfined Release
/// build (`LaunchOptions.isUnconfinedRelease`), so a development build never
/// offers to replace itself with a release. The target of "Check for
/// Updates…" in the app menu, which it enables when it can check (ADR 0081);
/// an `ObservableObject` for the toggle in Settings.
@MainActor
final class AppUpdater: NSObject, ObservableObject, NSMenuItemValidation {
    /// Whether "Check for Updates…" can run now: the updater started and is not busy.
    @Published private(set) var canCheckForUpdates = false
    /// Whether Sparkle looks for a new version once a day by itself; it writes
    /// through to Sparkle.
    @Published var checksAutomatically = false {
        didSet { controller.updater.automaticallyChecksForUpdates = checksAutomatically }
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
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Looks for a new version now and shows what it finds.
    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        canCheckForUpdates
    }
}
