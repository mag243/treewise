import SwiftUI
import TreewiseUI

/// Settings' Names pane: the saved patterns (ADR 0068), names with personal data
/// (ADR 0060) and clearing folder settings (ADR 0072). Changes apply at once.
struct SettingsNamesPane: View {
    @Bindable var settings: BrowserSettings

    /// The saved patterns, which may grow past the window and then scroll, and names
    /// with personal data.
    var body: some View {
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
        .frame(width: SettingsWindow.paneSize.width, height: SettingsWindow.paneSize.height)
    }
}
