import TreewiseUI

/// What every window shares: the settings, the clipboard (ADR 0037) and the
/// updater (ADR 0032).
@MainActor
enum AppServices {
    static let settings = BrowserSettings(store: LaunchOptions.settingsStore)
    static let clipboard = SharedClipboard()
    static let updater = AppUpdater()
}
