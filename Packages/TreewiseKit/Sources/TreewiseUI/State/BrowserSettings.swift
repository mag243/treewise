import Foundation
import Observation
import TreewiseCore

/// The settings of the browser windows (ADR 0022, ADR 0023). Every change is
/// kept in the store at once.
@MainActor
@Observable
public final class BrowserSettings {
    private enum Key {
        static let showsHiddenFiles = "showsHiddenFiles"
        static let showsExtensions = "showsExtensions"
        static let expandsSidebarToOpenFolder = "expandsSidebarToOpenFolder"
        static let rowDensity = "rowDensity"
        static let startFolder = "startFolder"
        static let doubleClickOpensIn = "doubleClickOpensIn"
        static let showsDetails = "showsDetails"
        static let lastSession = "lastSession"
        static let favoriteFolders = "favoriteFolders"
        static let sidebarWidth = "sidebarWidth"
        static let terminalApp = "terminalApp"
        static let checksSpellingWhileTyping = "checksSpellingWhileTyping"
        /// The single default pattern kept before the saved patterns, read when there
        /// is no list yet (ADR 0068).
        static let defaultNamePattern = "defaultNamePattern"
        static let savedPatterns = "savedPatterns"
        static let addOns = "addOns"
        static let licenceKeys = "licenceKeys"
        static let licenceTrialStarts = "licenceTrialStarts"
        /// The one trial start of ADR 0071, forgotten since ADR 0088.
        static let oldLicenceTrialStart = "licenceTrialStart"
        static let personalDataInNames = "personalDataInNames"
        static let offersMissingFolders = "offersMissingFolders"
        static let showsNameReviewPanel = "nameReviewShowsPanel"
        static let showsNameReviewAddOns = "nameReviewAddOnsOpen"
        /// Where 0.2 kept its one window (ADR 0024), read when there is no session.
        static let lastWindow = "lastWindow"
    }

    @ObservationIgnored private let store: any SettingsStoring

    /// Whether lists and the sidebar show hidden items.
    public var showsHiddenFiles: Bool {
        didSet { store.setSetting(String(showsHiddenFiles), for: Key.showsHiddenFiles) }
    }
    /// Whether names show their extension (`DisplayName`).
    public var showsExtensions: Bool {
        didSet { store.setSetting(String(showsExtensions), for: Key.showsExtensions) }
    }
    /// Whether the sidebar's tree opens down to the folder a tab shows.
    public var expandsSidebarToOpenFolder: Bool {
        didSet {
            store.setSetting(
                String(expandsSidebarToOpenFolder), for: Key.expandsSidebarToOpenFolder)
        }
    }
    /// How tall the list's rows are.
    public var rowDensity: RowDensity {
        didSet { store.setSetting(rowDensity.rawValue, for: Key.rowDensity) }
    }
    /// The folder a new window starts at; `nil` for home.
    public var startFolder: FileItem.ID? {
        didSet { store.setSetting(startFolder?.rawValue, for: Key.startFolder) }
    }
    /// Where a double-clicked folder opens: `.samePane` or `.otherPane`.
    public var doubleClickOpensIn: OpenPlacement {
        didSet {
            store.setSetting(
                doubleClickOpensIn == .otherPane ? "otherPane" : "samePane",
                for: Key.doubleClickOpensIn)
        }
    }

    /// Whether windows show the details pane at their right (M5b).
    public var showsDetails: Bool {
        didSet { store.setSetting(String(showsDetails), for: Key.showsDetails) }
    }

    /// The bundle identifier of the terminal Open in Terminal uses (ADR 0052);
    /// `nil` for the system's Terminal.
    public var terminalApp: String? {
        didSet { store.setSetting(terminalApp, for: Key.terminalApp) }
    }

    /// Whether a name being typed shows its misspelled words (ADR 0084); off, a name's
    /// spelling is checked only when the user asks.
    public var checksSpellingWhileTyping: Bool {
        didSet {
            store.setSetting(
                String(checksSpellingWhileTyping), for: Key.checksSpellingWhileTyping)
        }
    }

    /// The user's named patterns, one of them the default (ADR 0068).
    public var savedPatterns: SavedPatterns {
        didSet {
            store.setSetting(Self.json(savedPatterns), for: Key.savedPatterns)
        }
    }

    /// What the user chose for the add-ons across the app (ADR 0070).
    public var addOns: AddOnPreferences {
        didSet {
            store.setSetting(Self.json(addOns), for: Key.addOns)
        }
    }

    /// The licence keys the user entered, which the closed modules check (ADR 0071).
    public var licenceKeys: [String] {
        didSet {
            store.setSetting(Self.json(licenceKeys), for: Key.licenceKeys)
        }
    }

    /// When the user started each paid add-on's trial, by its id, as ISO 8601, kept here
    /// and in the keychain (ADR 0071, ADR 0088).
    public var licenceTrialStarts: [String: String] {
        didSet {
            store.setSetting(Self.json(licenceTrialStarts), for: Key.licenceTrialStarts)
        }
    }

    /// The pattern a folder without one of its own gets when the user asks for it, or
    /// when names are suggested for selected files there (ADR 0057): the saved default.
    public var defaultNamePattern: String { savedPatterns.defaultPattern.text }

    /// What Approve All does with a proposed name that holds personal data (ADR 0060).
    public var personalDataInNames: PersonalDataInNames {
        didSet { store.setSetting(personalDataInNames.rawValue, for: Key.personalDataInNames) }
    }

    /// Whether the name review shows its panel beside the list.
    public var showsNameReviewPanel: Bool {
        didSet { store.setSetting(String(showsNameReviewPanel), for: Key.showsNameReviewPanel) }
    }
    /// Whether the name review shows its add-ons open, after the first review of a folder.
    public var showsNameReviewAddOns: Bool {
        didSet { store.setSetting(String(showsNameReviewAddOns), for: Key.showsNameReviewAddOns) }
    }

    /// Whether a year's folder offers, in its bar, the folders of the year before it lacks
    /// (ADR 0102); off, Add Missing Folders… still offers them.
    public var offersMissingFolders: Bool {
        didSet {
            store.setSetting(String(offersMissingFolders), for: Key.offersMissingFolders)
        }
    }

    /// The Favorites the user chose, as JSON (ADR 0050); `nil` until the first
    /// change, while the provider's built-in favorites show.
    public var favoriteFolders: [FileItem.ID]? {
        didSet {
            store.setSetting(
                favoriteFolders.flatMap { Self.json($0.map(\.rawValue)) }, for: Key.favoriteFolders)
        }
    }

    /// The sidebar width the user last dragged to, for a new window (ADR 0093); nil before
    /// a drag.
    public var sidebarWidth: Double? {
        didSet { store.setSetting(sidebarWidth.map { String($0) }, for: Key.sidebarWidth) }
    }

    /// The windows and tabs, for the next launch to restore (ADR 0038); kept
    /// as JSON, and not observed, as it changes with every folder shown. A
    /// session without windows is not kept, so the one before it stays.
    public var lastSession: SessionSnapshot? {
        get {
            if let session = decoded(SessionSnapshot.self, at: Key.lastSession) { return session }
            return decoded(WindowSnapshot.self, at: Key.lastWindow).map(SessionSnapshot.init)
        }
        set {
            guard let newValue, !newValue.groups.isEmpty, let json = Self.json(newValue) else {
                return
            }
            store.setSetting(json, for: Key.lastSession)
        }
    }

    /// Reads the settings from `store`; a missing value is its default.
    public init(store: any SettingsStoring) {
        self.store = store
        showsHiddenFiles = store.setting(Key.showsHiddenFiles) == "true"
        showsExtensions = store.setting(Key.showsExtensions) != "false"
        expandsSidebarToOpenFolder = store.setting(Key.expandsSidebarToOpenFolder) != "false"
        rowDensity = store.setting(Key.rowDensity).flatMap(RowDensity.init) ?? .medium
        startFolder = store.setting(Key.startFolder).map { FileItem.ID($0) }
        doubleClickOpensIn =
            store.setting(Key.doubleClickOpensIn) == "otherPane" ? .otherPane : .samePane
        showsDetails = store.setting(Key.showsDetails) == "true"
        showsNameReviewPanel = Self.isOn(store.setting(Key.showsNameReviewPanel))
        showsNameReviewAddOns = Self.isOn(store.setting(Key.showsNameReviewAddOns))
        terminalApp = store.setting(Key.terminalApp)
        checksSpellingWhileTyping = store.setting(Key.checksSpellingWhileTyping) == "true"
        savedPatterns =
            Self.decoded(SavedPatterns.self, at: Key.savedPatterns, in: store)
            ?? store.setting(Key.defaultNamePattern).map { SavedPatterns(keeping: $0) }
            ?? .examples()
        licenceKeys = Self.decoded([String].self, at: Key.licenceKeys, in: store) ?? []
        licenceTrialStarts =
            Self.decoded([String: String].self, at: Key.licenceTrialStarts, in: store) ?? [:]
        store.setSetting(nil, for: Key.oldLicenceTrialStart)
        addOns =
            Self.decoded(AddOnPreferences.self, at: Key.addOns, in: store) ?? AddOnPreferences()
        personalDataInNames =
            store.setting(Key.personalDataInNames).flatMap(PersonalDataInNames.init)
            ?? .leaveOutOfApproveAll
        favoriteFolders = Self.decoded([String].self, at: Key.favoriteFolders, in: store)?
            .map { FileItem.ID($0) }
        sidebarWidth = store.setting(Key.sidebarWidth).flatMap(Double.init)
        offersMissingFolders = store.setting(Key.offersMissingFolders) != "false"
    }

    /// A setting that is on unless turned off, kept as `false`, or as `0` by a boolean.
    private static func isOn(_ text: String?) -> Bool {
        text != "false" && text != "0"
    }

    private func decoded<Value: Decodable>(_ type: Value.Type, at key: String) -> Value? {
        Self.decoded(type, at: key, in: store)
    }

    /// A setting kept as JSON, or nil when there is none or it cannot be read.
    private static func decoded<Value: Decodable>(
        _ type: Value.Type, at key: String, in store: any SettingsStoring
    ) -> Value? {
        store.setting(key).flatMap { try? JSONDecoder().decode(type, from: Data($0.utf8)) }
    }

    /// A value as the JSON text a setting keeps.
    private static func json<Value: Encodable>(_ value: Value) -> String? {
        (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The folder a new window starts at: the chosen one when `lookUp` finds
    /// it and it is a folder, else `home`. `lookUp` returns `nil` for an item
    /// that is gone or outside the boundary.
    public func startFolder(home: FileItem.ID, lookUp: (FileItem.ID) -> FileItem?) -> FileItem.ID {
        guard let startFolder, lookUp(startFolder)?.isContainer == true else { return home }
        return startFolder
    }
}
