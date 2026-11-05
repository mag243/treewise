import SwiftUI
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// The iPad app's shell (ADR 0045): the added folders in the sidebar, the
/// folder shown beside them, and Add Location, which opens the document
/// picker for a folder.
struct RootView: View {
    let locations: Locations
    @State private var isPickingFolder = false

    var body: some View {
        NavigationSplitView {
            LocationsSidebar(locations: locations, addLocation: { isPickingFolder = true })
        } detail: {
            if let browser = locations.browser {
                FolderView(browser: browser, settings: locations.settings)
            } else if locations.isLoaded {
                NoLocationsView(addLocation: { isPickingFolder = true })
            }
        }
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task { await locations.add(url) }
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
}

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
