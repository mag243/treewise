import Combine
import Sparkle
import SwiftUI

/// Sparkle's updater (ADR 0032). It starts only in an unconfined Release
/// build (`LaunchOptions.isUnconfinedRelease`), so a development build never
/// offers to replace itself with a release. An `ObservableObject`, as in
/// Sparkle's SwiftUI guide, so the menu item follows its `@Published` changes
/// through `@ObservedObject`.
@MainActor
final class AppUpdater: ObservableObject {
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

    init() {
        isRunning = LaunchOptions.isUnconfinedRelease
        guard isRunning else { return }
        controller.startUpdater()
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Looks for a new version now and shows what it finds.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// "Check for Updates…" in the app menu, after About Treewise (ADR 0032).
struct UpdateCommands: Commands {
    let updater: AppUpdater

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            CheckForUpdatesButton(updater: updater)
        }
    }
}

/// The menu item as a view that observes the updater, as Sparkle's guide
/// shows; the `Commands` body itself is not updated when the updater changes.
private struct CheckForUpdatesButton: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!updater.canCheckForUpdates)
    }
}
