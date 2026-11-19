import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import UniformTypeIdentifiers

/// The iPad app's shell (ADR 0045): the added folders in the sidebar, the
/// folder shown beside them, and Add Location, which opens the document
/// picker for a folder; the same picker connects a folder that could not be
/// reached again (ADR 0111). Each window shows its own folder (ADR 0134).
struct RootView: View {
    let locations: Locations
    /// What the window presents, which iPadOS keeps to restore it.
    @Binding var request: WindowRequest
    @State private var isPickingFolder = false
    /// The unavailable folder the picker connects again; `nil` while it adds one.
    @State private var reconnecting: Bookmark?
    @State private var isShowingSettings = false
    /// The screen shown where the sidebar and the folder are one stack, as on the iPhone
    /// (ADR 0132): the folder, until the user goes back to the locations.
    @State private var compactColumn = NavigationSplitViewColumn.detail
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.scenePhase) private var scenePhase

    private var window: BrowserWindow { locations.window(for: request) }

    var body: some View {
        splitView
            // Where only the height is compact, as on a Pro Max in landscape, the
            // iPhone's layout stays (ADR 0132); an iPad's height is never compact.
            .environment(\.horizontalSizeClass, heightClass == .compact ? .compact : widthClass)
            .task { await locations.open(request) }
            .onDisappear { locations.close(request) }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { locations.activate(request) }
            }
            .onChange(of: scenePhase) { _, phase in
                // The window keeps where it is for iPadOS to restore it.
                if phase == .background { keepWhereTheWindowIs() }
            }
    }

    private var splitView: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            LocationsSidebar(
                locations: locations, window: window, addLocation: { pick(for: nil) },
                reconnect: { pick(for: $0) }, showSettings: { isShowingSettings = true },
                showFolder: { compactColumn = .detail })
        } detail: {
            if let browser = window.browser {
                FolderView(
                    browser: browser, settings: locations.settings, locations: locations,
                    window: window)
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
                    await locations.reconnect(bookmark, to: url, in: window)
                } else {
                    await locations.add(url, in: window)
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheet(settings: locations.settings)
        }
        .modifier(LocationNameAlert(locations: locations, window: window))
        .alert(
            window.dropRefusal ?? "",
            isPresented: Binding(
                get: { window.dropRefusal != nil },
                set: { if !$0 { window.dropRefusal = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
        .alert(
            "The folder can’t be added.",
            isPresented: Binding(
                get: { window.addFailure != nil },
                set: { if !$0 { window.addFailure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(window.addFailure ?? "")
        }
    }

    /// Puts where the window is in its request, when that changed, as iPadOS keeps the
    /// request to restore the window.
    private func keepWhereTheWindowIs() {
        guard let snapshot = window.browser?.snapshot, snapshot != request.opening else {
            return
        }
        request = WindowRequest(id: request.id, showing: snapshot)
    }

    private func pick(for bookmark: Bookmark?) {
        reconnecting = bookmark
        isPickingFolder = true
    }
}
