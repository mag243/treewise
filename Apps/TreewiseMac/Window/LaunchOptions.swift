import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// How the app was started. Both options confine the window to a boundary
/// (ADR 0019), so playtests and UI tests never show or touch the user's folders:
/// - `-TreewiseRoot <folder>`: the folder is home and boundary, without
///   Applications or volumes (UI tests).
/// - `-TreewiseSandbox <volume>:<volume>`: the sandbox volumes of
///   `tools/build.sh sandbox` are the boundary, and the locations while they
///   are mounted (ADR 0046), with home and Applications on the first.
/// Screenshots (ADR 0041) add `-TreewiseFreshSettings YES`,
/// `-TreewiseWindowSize <width>x<height>` and `-TreewiseAppearance light|dark`.
/// A Debug build takes `-TreewiseTrialStart yyyy-MM-dd`, to try a trial's days (ADR 0071).
enum LaunchOptions {
    private static let rootArgument = "TreewiseRoot"
    private static let sandboxArgument = "TreewiseSandbox"
    private static let freshSettingsArgument = "TreewiseFreshSettings"
    private static let windowSizeArgument = "TreewiseWindowSize"
    private static let appearanceArgument = "TreewiseAppearance"
    private static let trialStartArgument = "TreewiseTrialStart"
    /// The keychain service of the sandbox's licence dates, apart from the real ones.
    private static let sandboxKeychainService = KeychainStore.appService + ".sandbox"
    /// Where the demo tree has its home folder on the first sandbox volume.
    private static let sandboxHome = "Users/Home"
    /// The defaults suite of the sandbox's settings, apart from the real ones.
    private static let sandboxSettingsSuite = "me.m-domain.treewise.sandbox"
    /// The end of the name of a temporary folder of folder settings.
    private static let folderSettingsSuffix = "-folder-settings"
    /// The folder of the sandbox's folder settings, inside the real ones' folder.
    private static let sandboxFolderSettings = "Sandbox"

    /// The folder given with `-TreewiseRoot`, standardized, if any.
    static var root: URL? {
        UserDefaults.standard.string(forKey: rootArgument).map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
    }

    /// The volumes given with `-TreewiseSandbox`, if any.
    static var sandboxVolumes: [URL] {
        let paths =
            UserDefaults.standard.string(forKey: sandboxArgument)?.split(separator: ":") ?? []
        return paths.map { URL(fileURLWithPath: String($0)).standardizedFileURL }
    }

    /// Where the sidebar's folders and volumes come from, and the boundary.
    static var locations: LocalFileSystem.Locations {
        if let root {
            return LocalFileSystem.Locations(
                home: root, applications: root.appendingPathComponent("Applications"),
                mountedVolumes: { [] }, boundary: [root])
        }
        let volumes = sandboxVolumes
        guard let first = volumes.first else { return .system }
        return LocalFileSystem.Locations(
            home: first.appendingPathComponent(sandboxHome),
            applications: first.appendingPathComponent("Applications"),
            mountedVolumes: { LocalFileSystem.Locations.systemVolumes(among: volumes) },
            boundary: volumes)
    }

    /// The folders the window is confined to, or `nil` for the whole disk.
    static var boundary: [URL]? {
        locations.boundary
    }

    /// Whether this is a Release build running unconfined, as users run it:
    /// only then may Treewise update itself (ADR 0032) or offer to move to
    /// Applications (ADR 0034). Debug builds, UI tests and the sandbox never do.
    static var isUnconfinedRelease: Bool {
        #if DEBUG
            false
        #else
            boundary == nil
        #endif
    }

    /// The folder new tabs open at, and a new window unless the settings
    /// choose another start folder.
    static var homeFolder: URL {
        locations.home
    }

    /// The size of each new window's content, from `-TreewiseWindowSize
    /// 1280x800`, for screenshots of the same size every time (ADR 0041); such
    /// a window opens on the main display.
    static var windowSize: CGSize? {
        let parts =
            UserDefaults.standard.string(forKey: windowSizeArgument)?.split(separator: "x")
            .compactMap { Double($0) } ?? []
        guard parts.count == 2 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    /// Light or dark for Treewise whatever the system uses, from
    /// `-TreewiseAppearance light|dark`, for screenshots (ADR 0041).
    static var appearance: NSAppearance? {
        switch UserDefaults.standard.string(forKey: appearanceArgument) {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }

    /// Where the settings are kept (ADR 0023): in memory for `-TreewiseRoot`
    /// and `-TreewiseFreshSettings`, so UI tests and screenshots start from the
    /// defaults; in a suite of their own for the sandbox; else in the standard
    /// defaults.
    @MainActor static let settingsStore: any SettingsStoring = {
        if root != nil || UserDefaults.standard.bool(forKey: freshSettingsArgument) {
            return MemorySettingsStore()
        }
        if !sandboxVolumes.isEmpty, let suite = UserDefaults(suiteName: sandboxSettingsSuite) {
            return suite
        }
        return UserDefaults.standard
    }()

    /// Where the licence dates are kept beside the settings (ADR 0071): as the settings
    /// are, in memory for UI tests and screenshots, apart for the sandbox, else in the
    /// keychain.
    @MainActor static let secureStore: any SecureValueStoring = {
        if root != nil || UserDefaults.standard.bool(forKey: freshSettingsArgument) {
            return MemorySecureStore()
        }
        if !sandboxVolumes.isEmpty { return KeychainStore(service: sandboxKeychainService) }
        return KeychainStore()
    }()

    /// Where the folder settings are kept (ADR 0057, ADR 0072): as the settings are, apart
    /// from the real ones for UI tests, screenshots and the sandbox, so none of them reads,
    /// changes or clears the user's. A UI test's folder is named after its root, so a
    /// test that starts the app again finds what it saved.
    static var folderSettingsDirectory: URL {
        let temporary = FileManager.default.temporaryDirectory
        if let root {
            return temporary.appendingPathComponent(
                root.lastPathComponent + folderSettingsSuffix, isDirectory: true)
        }
        if UserDefaults.standard.bool(forKey: freshSettingsArgument) {
            return temporary.appendingPathComponent(
                UUID().uuidString + folderSettingsSuffix, isDirectory: true)
        }
        if !sandboxVolumes.isEmpty {
            return FolderSettingsStore.defaultDirectory.appendingPathComponent(
                sandboxFolderSettings, isDirectory: true)
        }
        return FolderSettingsStore.defaultDirectory
    }

    /// The trial's start given at launch, in a Debug build only, to try a trial's days.
    static var trialStart: Date? {
        #if DEBUG
            UserDefaults.standard.string(forKey: trialStartArgument).flatMap {
                try? Date($0, strategy: .iso8601.year().month().day())
            }
        #else
            nil
        #endif
    }

    /// The app's licences, kept as above (ADR 0071).
    @MainActor static func licenceKeeper(for settings: BrowserSettings) -> LicenceKeeper {
        LicenceKeeper(settings: settings, secure: secureStore, trialStart: trialStart)
    }
}
