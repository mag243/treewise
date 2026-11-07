import SwiftUI

/// The section of Settings that clears what Treewise keeps for each folder it suggested
/// names in, after asking (ADR 0072). Saved patterns stay.
struct FolderSettingsSection: View {
    @State private var confirmsClear = false

    var body: some View {
        Section {
            Button("Clear Folder Settings…") { confirmsClear = true }
        } footer: {
            Text(
                "For each folder you suggest names in, Treewise keeps which add-ons are on and their patterns. Those of a folder not seen for 30 days go by themselves."
            )
            .font(.caption).foregroundStyle(.secondary)
        }
        .confirmationDialog("Clear the settings of every folder?", isPresented: $confirmsClear) {
            Button("Clear Folder Settings", role: .destructive) {
                Task { await NameReviewWindow.store.clearAll() }
            }
        } message: {
            Text(
                "Each folder starts again with the add-ons that are on in new folders, and its pattern is recognized again. Saved patterns stay."
            )
        }
    }
}
