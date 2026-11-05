import SwiftUI
import TreewiseCore
import TreewiseUI

/// The sidebar: the added folders, the one holding the folder shown selected,
/// with Add Location and Remove Location.
struct LocationsSidebar: View {
    let locations: Locations
    let addLocation: () -> Void

    var body: some View {
        List(selection: selection) {
            Section("Locations") {
                ForEach(locations.browser?.locations ?? []) { location in
                    Label(location.name, systemImage: ItemSymbol.name(for: location))
                        .tag(location.id)
                        .contextMenu {
                            removeButton(location)
                        }
                        .swipeActions {
                            removeButton(location)
                        }
                }
            }
        }
        .navigationTitle(Text(verbatim: "Treewise"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addLocation) {
                    Label("Add Location", systemImage: "plus")
                }
            }
        }
    }

    private func removeButton(_ location: FileItem) -> some View {
        Button(role: .destructive) {
            Task { await locations.remove(location) }
        } label: {
            Label("Remove Location", systemImage: "minus.circle")
        }
    }

    /// The location the folder shown is in; choosing one shows it.
    private var selection: Binding<FileItem.ID?> {
        Binding(
            get: { locations.browser?.locationShown(in: 0) },
            set: { location in
                guard let location, let browser = locations.browser else { return }
                Task { await browser.navigate(pane: 0, to: location) }
            })
    }
}
