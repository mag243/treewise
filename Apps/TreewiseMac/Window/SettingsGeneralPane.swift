import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// Settings' General pane: where folders open, the start folder, and how the list
/// shows items (ADR 0022, ADR 0023), checking for updates (ADR 0032), the terminal to
/// open (ADR 0052), the way to change shortcuts (ADR 0029), and syncing settings through
/// the cloud drives with its safety net (ADR 0144). Changes apply at once.
@MainActor
final class SettingsGeneralPane: NSViewController {
    /// The Keyboard pane of System Settings, where App Shortcuts live (ADR 0029).
    private static let keyboardSettings = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    private static let placements: [OpenPlacement] = [.samePane, .otherPane]
    private static let densities: [RowDensity] = [.small, .medium, .large]

    private let settings: BrowserSettings
    private let updater: AppUpdater
    private let sync: SyncController
    private lazy var placement = SettingsForm.popUp(
        [String(localized: "This window"), String(localized: "The other window")],
        accessibilityLabel: "Double-click opens folders in"
    ) { [settings] in settings.doubleClickOpensIn = Self.placements[$0] }
    private let startFolder = NSTextField(labelWithString: "")
    private lazy var homeButton = SettingsForm.button("Home") { [settings] in
        settings.startFolder = nil
    }
    private lazy var hiddenFiles = SettingsForm.checkbox("Show hidden files") { [settings] in
        settings.showsHiddenFiles = $0
    }
    private lazy var extensions = SettingsForm.checkbox("Show file extensions") { [settings] in
        settings.showsExtensions = $0
    }
    private lazy var expandsSidebar = SettingsForm.checkbox(
        "Expand sidebar to open folder"
    ) { [settings] in settings.expandsSidebarToOpenFolder = $0 }
    private lazy var rowSize = SettingsForm.popUp(
        [String(localized: "Small"), String(localized: "Medium"), String(localized: "Large")],
        accessibilityLabel: "Row size"
    ) { [settings] in settings.rowDensity = Self.densities[$0] }
    private lazy var terminal = SettingsForm.popUp(
        TerminalOpener.installedApps.map(\.name), accessibilityLabel: "Terminal app"
    ) { [settings] in settings.terminalApp = TerminalOpener.installedApps[$0].id }
    private lazy var syncs = SettingsForm.checkbox(
        "Sync settings through cloud drives"
    ) { [sync] in Self.setSyncing($0, in: sync) }
    private let replacedCount = NSTextField(labelWithString: "")
    /// The row of `replacedLine`, hidden whole while nothing was replaced, so it takes no room.
    private var replacedRow: NSGridRow?
    private let renamedNote = NSTextField(wrappingLabelWithString: "")
    /// The row of `renamedNote`, shown only when a drive renamed Treewise's folder.
    private var renamedRow: NSGridRow?
    private lazy var replacedLine: NSStackView = {
        let review = SettingsForm.button("Review…") { [weak self] in self?.reviewReplaced() }
        return Self.line([replacedCount, review])
    }()
    private lazy var updates = SettingsForm.checkbox(
        "Check for updates automatically"
    ) { [updater] in updater.checksAutomatically = $0 }

    init(settings: BrowserSettings, updater: AppUpdater, sync: SyncController) {
        self.settings = settings
        self.updater = updater
        self.sync = sync
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let form = SettingsForm()
        form.row("Double-click opens folders in:", placement)
        startFolder.textColor = .secondaryLabelColor
        let choose = SettingsForm.button("Choose…") { [weak self] in self?.chooseStartFolder() }
        form.row("New windows open at:", Self.line([startFolder, choose, homeButton]))
        form.group()
        form.row(nil, hiddenFiles)
        form.row(nil, extensions)
        form.row(nil, expandsSidebar)
        form.row("Row size:", rowSize)
        form.group()
        form.row("Terminal app:", terminal)
        form.group()
        updates.isEnabled = updater.isRunning
        form.row(nil, updates)
        form.group()
        form.row("Sync:", syncs)
        form.note(
            "Folder settings, saved patterns and templates are kept in a hidden .treewise.settings folder in iCloud Drive, Dropbox and your other cloud drives, so your other Macs and your iPad have them too.",
            width: SettingsForm.noteWidth)
        replacedRow = form.row(nil, replacedLine)
        renamedNote.textColor = .secondaryLabelColor
        renamedNote.preferredMaxLayoutWidth = SettingsForm.noteWidth
        renamedRow = form.row(nil, renamedNote)
        form.group()
        let customize = SettingsForm.button("Customize…") {
            if let url = Self.keyboardSettings { NSWorkspace.shared.open(url) }
        }
        form.row("Keyboard shortcuts:", customize)
        form.note(
            "In Keyboard Shortcuts, choose App Shortcuts, add Treewise and type the name of a menu item as the menu shows it.",
            width: SettingsForm.noteWidth)
        view = form.pane(size: SettingsWindow.paneSize)
        Observing.follow(self) { $0.update() }
    }

    private func update() {
        placement.selectItem(at: Self.placements.firstIndex(of: settings.doubleClickOpensIn) ?? 0)
        startFolder.stringValue = startFolderName
        homeButton.isEnabled = settings.startFolder != nil
        hiddenFiles.state = settings.showsHiddenFiles ? .on : .off
        extensions.state = settings.showsExtensions ? .on : .off
        expandsSidebar.state = settings.expandsSidebarToOpenFolder ? .on : .off
        rowSize.selectItem(at: Self.densities.firstIndex(of: settings.rowDensity) ?? 0)
        let chosen = TerminalOpener.chosenApp(in: settings)
        terminal.selectItem(at: TerminalOpener.installedApps.firstIndex { $0.id == chosen } ?? 0)
        updates.state = updater.checksAutomatically ? .on : .off
        syncs.state = settings.syncsSettings ? .on : .off
        let replaced = sync.replaced.count
        replacedRow?.isHidden = replaced == 0
        let renamed = sync.driveProblems.filter { $0.value == .renamed }.keys
            .map { URL(filePath: $0).lastPathComponent }.sorted()
        renamedRow?.isHidden = renamed.isEmpty
        renamedNote.stringValue = String(
            localized:
                "Not syncing in \(renamed.formatted(.list(type: .and))): the drive renamed Treewise's folder."
        )
        replacedCount.stringValue = String(
            localized: "Replaced by another device: \(replaced)")
    }

    private static func setSyncing(_ isOn: Bool, in sync: SyncController) {
        Task { await sync.setSyncing(isOn) }
    }

    /// The safety net's list with Restore, as a sheet (ADR 0144).
    private func reviewReplaced() {
        presentAsSheet(SyncReplacedSheet(sync: sync, settings: settings))
    }

    private static func line(_ views: [NSView]) -> NSStackView {
        let line = NSStackView(views: views)
        line.alignment = .firstBaseline
        return line
    }

    private var startFolderName: String {
        guard let folder = settings.startFolder else { return String(localized: "Home") }
        return folder.urlShownInFinder.lastPathComponent
    }

    /// Asks for a folder; one outside the folders Treewise may use is refused (ADR 0019).
    private func chooseStartFolder() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = LaunchOptions.homeFolder
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let id = FileItem.ID(url.standardizedFileURL.path)
            // After the panel's sheet has gone, so a refusal can show as a sheet of its own.
            Task { @MainActor in self?.useStartFolder(id, in: window) }
        }
    }

    private func useStartFolder(_ id: FileItem.ID, in window: NSWindow) {
        guard LocalFileSystem(locations: LaunchOptions.locations).isInsideBoundary(id) else {
            let alert = NSAlert()
            alert.messageText = FailureMessage.text(
                for: .outsideBoundary(id), locale: .autoupdatingCurrent)
            alert.beginSheetModal(for: window)
            return
        }
        settings.startFolder = id
    }
}
