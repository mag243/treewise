import AppKit
import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The Settings window (⌘,), in two tabs. General: where folders open, the start folder,
/// and how the list shows items (ADR 0022, ADR 0023), checking for updates (ADR 0032),
/// the terminal to open (ADR 0052) and the way to change shortcuts (ADR 0029). Names: the
/// saved patterns (ADR 0068), names with personal data (ADR 0060) and clearing folder
/// settings (ADR 0072). Add-ons: which are offered, on in new folders and in what order
/// (ADR 0070). Changes apply at once.
struct SettingsView: View {
    /// Wide enough for long add-on names and patterns.
    private static let width: CGFloat = 600
    /// The least height of every tab, so lists such as the saved patterns have room.
    private static let minimumHeight: CGFloat = 560
    /// The tallest the window gets; beyond it, its contents scroll.
    private static let maximumHeight: CGFloat = 760
    /// The Keyboard pane of System Settings, where App Shortcuts live (ADR 0029).
    private static let keyboardSettings = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")

    @Bindable var settings: BrowserSettings
    @ObservedObject var updater: AppUpdater
    @State private var refusal: String?
    /// The tab shown, General each time Settings opens, so its height is known first.
    @State private var tab = Tab.general
    /// The height of General's contents, measured once, which every tab takes, so the
    /// window keeps its size from tab to tab; a longer tab scrolls.
    @State private var height: CGFloat?

    private enum Tab {
        case general, names, addOns
    }

    var body: some View {
        TabView(selection: $tab) {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)
            names
                .frame(width: Self.width, height: tabHeight)
                .tabItem { Label("Names", systemImage: "textformat") }
                .tag(Tab.names)
            AddOnsSettingsTab(
                settings: settings, licences: LaunchOptions.licenceKeeper(for: settings)
            )
            .frame(width: Self.width, height: tabHeight)
            .tabItem { Label("Add-ons", systemImage: "puzzlepiece.extension") }
            .tag(Tab.addOns)
        }
        .alert(refusal ?? "", isPresented: isRefusing) {
            Button("OK") { refusal = nil }
        }
    }

    private var general: some View {
        Form {
            Section {
                Picker("Double-click opens folders in", selection: $settings.doubleClickOpensIn) {
                    Text("This window").tag(OpenPlacement.samePane)
                    Text("The other window").tag(OpenPlacement.otherPane)
                }
                LabeledContent("New windows open at") {
                    HStack {
                        Text(startFolderName).foregroundStyle(.secondary)
                        Button("Choose…", action: chooseStartFolder)
                        Button("Home") { settings.startFolder = nil }
                            .disabled(settings.startFolder == nil)
                    }
                }
            }
            Section {
                Toggle("Show hidden files", isOn: $settings.showsHiddenFiles)
                Toggle("Show file extensions", isOn: $settings.showsExtensions)
                Toggle(
                    "Expand sidebar to open folder", isOn: $settings.expandsSidebarToOpenFolder)
                Picker("Row size", selection: $settings.rowDensity) {
                    Text("Small").tag(RowDensity.small)
                    Text("Medium").tag(RowDensity.medium)
                    Text("Large").tag(RowDensity.large)
                }
            }
            Section {
                Picker("Terminal app", selection: terminalApp) {
                    ForEach(TerminalOpener.installedApps) { app in
                        Text(verbatim: app.name).tag(app.id)
                    }
                }
            }
            Section {
                Toggle("Check for updates automatically", isOn: $updater.checksAutomatically)
                    .disabled(!updater.isRunning)
            }
            Section {
                LabeledContent("Keyboard shortcuts") {
                    Button("Customize…") {
                        if let url = Self.keyboardSettings { NSWorkspace.shared.open(url) }
                    }
                }
            } footer: {
                Text(
                    "In Keyboard Shortcuts, choose App Shortcuts, add Treewise and type the name of a menu item as the menu shows it."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            // The form's margins are insets of its scroll view, outside its content size.
            (geometry.contentSize.height + geometry.contentInsets.top
                + geometry.contentInsets.bottom).rounded(.up)
        } action: { _, measured in
            // Taken once: the window's height changes what the scroll view reports, and
            // following that again and again crashes AppKit's layout.
            if height == nil, measured > 0 { height = measured }
        }
        .frame(width: Self.width, height: tabHeight)
    }

    private var tabHeight: CGFloat? {
        height.map { min(max($0, Self.minimumHeight), Self.maximumHeight) }
    }

    /// The saved patterns, which may grow past the window and then scroll, and names
    /// with personal data.
    private var names: some View {
        Form {
            SavedPatternsSection(settings: settings)
            Section {
                Picker("Names with personal data", selection: $settings.personalDataInNames) {
                    Text("Leave out of Approve All").tag(PersonalDataInNames.leaveOutOfApproveAll)
                    Text("Only warn").tag(PersonalDataInNames.onlyWarn)
                }
            } footer: {
                Text(
                    "A proposed name with an e-mail address, phone number, bank account or payment card number is marked. A name you type is not."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            FolderSettingsSection()
        }
        .formStyle(.grouped)
    }

    private var terminalApp: Binding<String> {
        Binding(
            get: { TerminalOpener.chosenApp(in: settings) },
            set: { settings.terminalApp = $0 })
    }

    private var startFolderName: String {
        guard let folder = settings.startFolder else { return String(localized: "Home") }
        return folder.urlShownInFinder.lastPathComponent
    }

    private var isRefusing: Binding<Bool> {
        Binding(get: { refusal != nil }, set: { if !$0 { refusal = nil } })
    }

    /// Asks for a folder; one outside the folders Treewise may use is refused (ADR 0019).
    private func chooseStartFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = LaunchOptions.homeFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let id = FileItem.ID(url.standardizedFileURL.path)
        guard LocalFileSystem(locations: LaunchOptions.locations).isInsideBoundary(id) else {
            refusal = FailureMessage.text(for: .outsideBoundary(id), locale: .autoupdatingCurrent)
            return
        }
        settings.startFolder = id
    }
}
