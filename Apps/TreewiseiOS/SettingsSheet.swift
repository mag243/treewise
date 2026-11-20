import SwiftUI
import TreewiseCore
import TreewiseUI

/// Settings, from the gear in the sidebar (ADR 0130, ADR 0143): tabs as the Mac's, Names and
/// Templates, and About in place of the Mac's About panel, at the top on the iPad and at the bottom on the iPhone. Changes apply at once.
struct SettingsSheet: View {
    let settings: BrowserSettings
    let undoManager: UndoManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            Tab(String(localized: "Names"), systemImage: "textformat") {
                NavigationStack { NamesSettings(settings: settings).toolbar { done } }
            }
            Tab(String(localized: "Templates"), systemImage: "folder.badge.gearshape") {
                NavigationStack {
                    TemplatesSettings(model: NameServices.templateList, undoManager: undoManager)
                        .toolbar { done }
                }
            }
            Tab(String(localized: "About"), systemImage: "info.circle") {
                NavigationStack { AboutSettings().toolbar { done } }
            }
        }
    }

    @ToolbarContentBuilder private var done: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }
}

/// The Names tab, as the Mac's Names pane: the saved patterns, names with personal data, and
/// clearing what Treewise keeps for each folder it suggested names in.
private struct NamesSettings: View {
    let settings: BrowserSettings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isAskingToClear = false

    var body: some View {
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
                .modifier(ChoicesAsRows(isShown: sizeClass == .compact))
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
        .navigationTitle(Text("Names"))
        .navigationBarTitleDisplayMode(.inline)
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

/// A picker's choices as rows with a check, where the width is compact and a menu's chosen
/// text would be cut off beside a long label (ADR 0132).
private struct ChoicesAsRows: ViewModifier {
    let isShown: Bool

    func body(content: Content) -> some View {
        if isShown {
            content.pickerStyle(.inline)
        } else {
            content
        }
    }
}
