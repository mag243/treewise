import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import UniformTypeIdentifiers

/// The sidebar: the added folders, the one holding the folder shown selected,
/// with Add Location and Remove Location, and greyed below them the folders that
/// could not be reached, to connect again (ADR 0111).
struct LocationsSidebar: View {
    /// Below this many locations, the sidebar says that one top folder is enough.
    private static let locationsBeforeHint = 2

    @Environment(\.horizontalSizeClass) private var sizeClass
    let locations: Locations
    let addLocation: () -> Void
    let reconnect: (Bookmark) -> Void
    /// Opens Settings (ADR 0130).
    let showSettings: () -> Void
    /// Shows the folder chosen, where the sidebar is a screen of its own (ADR 0132).
    var showFolder: () -> Void = {}

    var body: some View {
        List(selection: selection) {
            if let browser = locations.browser, let drops {
                FavoritesSection(browser: browser, drops: drops)
            }
            Section {
                ForEach(locations.browser?.locations ?? []) { location in
                    Label(location.name, systemImage: ItemSymbol.name(for: location))
                        .tag(location.id)
                        .contextMenu {
                            Button {
                                Task { await locations.rename(location) }
                            } label: {
                                Label("Rename Location…", systemImage: "pencil")
                            }
                            removeButton(location)
                        }
                        .swipeActions {
                            removeButton(location)
                        }
                        .modifier(LocationDrop(location: location, drops: drops))
                }
                ForEach(locations.unavailable) { bookmark in
                    unavailableRow(bookmark)
                }
            } header: {
                Text("Locations")
            } footer: {
                if shownLocations < Self.locationsBeforeHint, DeviceKind.isPhone {
                    Text(
                        "Add the top of iCloud Drive, On My iPhone or a drive: everything below it comes along."
                    )
                } else if shownLocations < Self.locationsBeforeHint {
                    Text(
                        "Add the top of iCloud Drive, On My iPad or a drive: everything below it comes along."
                    )
                }
            }
        }
        // The UI tests find the sidebar by it (ADR 0114).
        .accessibilityIdentifier("locations")
        .navigationTitle(Text(verbatim: "Treewise"))
        // A screen of its own where the width is compact, titled as Files is (ADR 0132).
        .navigationBarTitleDisplayMode(sizeClass == .compact ? .large : .automatic)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addLocation) {
                    Label("Add Location", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(action: showSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
                // The UI tests find it by it.
                .accessibilityIdentifier("settings")
            }
        }
    }

    private var drops: ItemDrops? {
        locations.browser.map {
            ItemDrops(browser: $0, locations: locations, undoManager: locations.undo.manager)
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

    /// The favorite shown, else the location the folder shown is in; choosing one shows it.
    private var selection: Binding<FileItem.ID?> {
        Binding(
            get: {
                guard let browser = locations.browser else { return nil }
                let folder = browser.layout.focusedPane.activeTab.folder
                return browser.isFavorite(folder) ? folder : browser.locationShown(in: 0)
            },
            set: { location in
                guard let location, let browser = locations.browser else { return }
                showFolder()
                Task { await browser.navigate(pane: 0, to: location) }
            })
    }
}

/// A location that takes items dragged inside Treewise, checked as they land (ADR 0047).
private struct LocationDrop: ViewModifier {
    let location: FileItem
    let drops: ItemDrops?

    func body(content: Content) -> some View {
        if let drops {
            content.takesDrops(on: location, with: drops)
        } else {
            content
        }
    }
}
