import AppKit
import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// Settings' General pane: where folders open, the start folder, and how the list
/// shows items (ADR 0022, ADR 0023), checking for updates (ADR 0032), the terminal to
/// open (ADR 0052) and the way to change shortcuts (ADR 0029). Changes apply at once.
struct SettingsGeneralPane: View {
    /// The Keyboard pane of System Settings, where App Shortcuts live (ADR 0029).
    private static let keyboardSettings = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")

    @Bindable var settings: BrowserSettings
    @ObservedObject var updater: AppUpdater

    var body: some View {
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
        .frame(width: SettingsWindow.paneSize.width, height: SettingsWindow.paneSize.height)
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

    /// Asks for a folder; one outside the folders Treewise may use is refused (ADR 0019).
    private func chooseStartFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = LaunchOptions.homeFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let id = FileItem.ID(url.standardizedFileURL.path)
        guard LocalFileSystem(locations: LaunchOptions.locations).isInsideBoundary(id) else {
            let alert = NSAlert()
            alert.messageText = FailureMessage.text(
                for: .outsideBoundary(id), locale: .autoupdatingCurrent)
            alert.runModal()
            return
        }
        settings.startFolder = id
    }
}
