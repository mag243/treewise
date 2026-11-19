import SwiftUI
import TreewiseCore

/// A location the user names: one just added whose folder's name is a UUID, or one
/// renamed from the sidebar (ADR 0119).
struct LocationNaming {
    /// The added folder.
    let folder: URL
    /// The name typed; empty gives the folder its own name back.
    var label: String
}

/// Asks in a window for the name of the location its `naming` names (ADR 0119). The name is
/// Treewise's own: the folder itself keeps its name.
struct LocationNameAlert: ViewModifier {
    let locations: Locations
    let window: BrowserWindow
    @State private var label = ""
    /// The folder asked about, kept apart from the window's `naming`, which the alert
    /// clears as it closes.
    @State private var folder: URL?

    func body(content: Content) -> some View {
        content
            .onChange(of: window.naming?.folder, initial: true) {
                label = window.naming?.label ?? ""
                folder = window.naming?.folder ?? folder
            }
            .alert(
                "Name Location",
                isPresented: Binding(
                    get: { window.naming != nil },
                    set: { if !$0 { window.naming = nil } })
            ) {
                TextField("Name", text: $label)
                Button("Save") { save() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Treewise shows this name instead of the folder’s, which keeps its own. iPadOS doesn’t tell Treewise which app a cloud folder belongs to, so name it after the app, such as Dropbox."
                )
            }
    }

    private func save() {
        guard let folder else { return }
        let naming = LocationNaming(folder: folder, label: label)
        Task { await locations.name(naming) }
    }
}
