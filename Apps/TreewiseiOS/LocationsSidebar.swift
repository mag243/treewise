import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The sidebar: the added folders, the one holding the folder shown selected,
/// with Add Location and Remove Location, and greyed below them the folders that
/// could not be reached, to connect again (ADR 0111).
struct LocationsSidebar: View {
    /// Below this many locations, the sidebar says that one top folder is enough.
    private static let locationsBeforeHint = 2

    let locations: Locations
    let addLocation: () -> Void
    let reconnect: (Bookmark) -> Void

    var body: some View {
        List(selection: selection) {
            Section {
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
                ForEach(locations.unavailable) { bookmark in
                    unavailableRow(bookmark)
                }
            } header: {
                Text("Locations")
            } footer: {
                if shownLocations < Self.locationsBeforeHint {
                    Text(
                        "Add the top of iCloud Drive, On My iPad or a drive: everything below it comes along."
                    )
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

    private var shownLocations: Int {
        (locations.browser?.locations.count ?? 0) + locations.unavailable.count
    }

    /// A folder that could not be reached: greyed, connected again by a tap or its menu.
    private func unavailableRow(_ bookmark: Bookmark) -> some View {
        Button {
            reconnect(bookmark)
        } label: {
            Label {
                Text(verbatim: bookmark.name ?? String(localized: "Unavailable Folder"))
            } icon: {
                Image(systemName: "folder.badge.questionmark")
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityHint(Text("Not available. Tap to connect it again."))
        .contextMenu {
            Button {
                reconnect(bookmark)
            } label: {
                Label("Reconnect…", systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) {
                Task { await locations.forget(bookmark) }
            } label: {
                Label("Remove Location", systemImage: "minus.circle")
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
