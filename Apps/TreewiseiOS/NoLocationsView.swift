import SwiftUI
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// What the app shows before a folder is added: how to add one.
struct NoLocationsView: View {
    let addLocation: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Locations", systemImage: "folder.badge.plus")
        } description: {
            Text(
                "Add a folder from On My iPad, iCloud Drive, a drive or another app to browse it in Treewise."
            )
        } actions: {
            Button("Add Location", action: addLocation)
                .buttonStyle(.borderedProminent)
        }
    }
}
