import Foundation
import TreewiseFileSystem
import TreewiseModuleXPC
import TreewiseUI

/// What the app shares across its windows, made here once: the settings, the clipboard
/// (ADR 0037), the updater (ADR 0032), the windows and their tabs, the connection to the
/// add-ons' service and the folder settings it keeps (ADR 0057), and the icon view's
/// thumbnails (ADR 0025).
@MainActor
enum AppServices {
    static let settings = BrowserSettings(store: LaunchOptions.settingsStore)
    static let clipboard = SharedClipboard()
    static let updater = AppUpdater()
    static let windows = WindowTabs()
    /// One connection to the add-ons' service, for every review and template.
    static let moduleHost = XPCModuleHost()
    static let folderSettings = FolderSettingsStore(
        directory: LaunchOptions.folderSettingsDirectory)
    static let thumbnails = ThumbnailCache()
    /// Folder settings, saved patterns and templates in sync through the cloud drives
    /// (ADR 0144).
    static let sync = SyncController(
        settings: settings,
        session: SyncSession(
            sync: SettingsSync(
                device: SyncDevice.load(
                    from: LaunchOptions.folderSettingsDirectory,
                    name: Host.current().localizedName ?? "Mac")),
            folders: folderSettings, templates: FolderTemplatesService.store),
        conflicts: SyncConflictStore(directory: LaunchOptions.folderSettingsDirectory))
}
