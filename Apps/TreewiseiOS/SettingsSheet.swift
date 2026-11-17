import SwiftUI
import TreewiseCore
import TreewiseUI

/// Settings, from the gear in the sidebar (ADR 0130): for now the Names section, as the
/// Mac's Names pane: the saved patterns, names with personal data, and clearing what
/// Treewise keeps for each folder it suggested names in. Changes apply at once.
struct SettingsSheet: View {
    let settings: BrowserSettings
    @Environment(\.dismiss) private var dismiss
    @State private var isAskingToClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        SavedPatternsList(settings: settings)
                    } label: {
                        LabeledContent(
                            String(localized: "Saved Patterns"),
                            value: settings.savedPatterns.defaultPattern.name)
                    }
                    // The UI tests find it by it.
                    .accessibilityIdentifier("savedPatterns")
                    Picker(
                        "Names with personal data",
                        selection: Binding(
                            get: { settings.personalDataInNames },
                            set: { settings.personalDataInNames = $0 })
                    ) {
                        Text("Leave out of Approve All").tag(
                            PersonalDataInNames.leaveOutOfApproveAll)
                        Text("Only warn").tag(PersonalDataInNames.onlyWarn)
                    }
                } header: {
                    Text("Names")
                } footer: {
                    Text(
                        "A proposed name with an e-mail address, phone number, bank account or payment card number is marked. A name you type is not."
                    )
                }
                Section {
                    Button("Clear Folder Settings…", role: .destructive) { isAskingToClear = true }
                } footer: {
                    Text(
                        "For each folder you suggest names in, Treewise keeps which add-ons are on and their patterns. Those of a folder not seen for 30 days go by themselves."
                    )
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Clear the settings of every folder?", isPresented: $isAskingToClear,
                titleVisibility: .visible
            ) {
                Button("Clear Folder Settings", role: .destructive) {
                    Task { await NameServices.folderSettings.clearAll() }
                }
            } message: {
                Text(
                    "Each folder starts again with the add-ons that are on in new folders, and its pattern is recognized again. Saved patterns stay."
                )
            }
        }
    }
}
