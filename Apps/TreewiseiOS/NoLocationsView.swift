import SwiftUI
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// What the app shows before a folder is added: that Treewise shows the folders it is
/// given, and that one top folder is enough (ADR 0111).
struct NoLocationsView: View {
    let addLocation: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Add a Location", systemImage: "folder.badge.plus")
        } description: {
            Text(
                "Treewise shows the folders you give it. Add the top of iCloud Drive, On My iPad or a drive: everything below it comes along, so once is enough."
            )
        } actions: {
            Button("Add Location", action: addLocation)
                .buttonStyle(.borderedProminent)
        }
    }
}
