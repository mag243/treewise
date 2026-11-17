import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import UniformTypeIdentifiers

/// The iPad app's shell (ADR 0045): the added folders in the sidebar, the
/// folder shown beside them, and Add Location, which opens the document
/// picker for a folder; the same picker connects a folder that could not be
/// reached again (ADR 0111).
struct RootView: View {
    let locations: Locations
    @State private var isPickingFolder = false
    /// The unavailable folder the picker connects again; `nil` while it adds one.
    @State private var reconnecting: Bookmark?
    @State private var isShowingSettings = false
    /// The screen shown where the sidebar and the folder are one stack, as on the iPhone
    /// (ADR 0132): the folder, until the user goes back to the locations.
    @State private var compactColumn = NavigationSplitViewColumn.detail

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            LocationsSidebar(
                locations: locations, addLocation: { pick(for: nil) },
                reconnect: { pick(for: $0) }, showSettings: { isShowingSettings = true },
                showFolder: { compactColumn = .detail })
        } detail: {
            if let browser = locations.browser {
                FolderView(browser: browser, settings: locations.settings, locations: locations)
            } else if locations.isLoaded {
                NoLocationsView(addLocation: { pick(for: nil) })
            }
        }
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            let bookmark = reconnecting
            reconnecting = nil
            guard case .success(let url) = result else { return }
            Task {
                if let bookmark {
                    await locations.reconnect(bookmark, to: url)
                } else {
                    await locations.add(url)
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheet(settings: locations.settings)
        }
        .modifier(LocationNameAlert(locations: locations))
        .alert(
            locations.dropRefusal ?? "",
            isPresented: Binding(
                get: { locations.dropRefusal != nil },
                set: { if !$0 { locations.dropRefusal = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
        .alert(
            "The folder can’t be added.",
            isPresented: Binding(
                get: { locations.addFailure != nil },
                set: { if !$0 { locations.addFailure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(locations.addFailure ?? "")
        }
    }

    private func pick(for bookmark: Bookmark?) {
        reconnecting = bookmark
        isPickingFolder = true
    }
}
