import SwiftUI

@main
struct TreewiseiOSApp: App {
    @State private var locations = Locations()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        // Every window presents a request of its own, which iPadOS keeps with the window
        // to restore it; a window the system opens gets a new one (ADR 0134).
        WindowGroup(for: WindowRequest.self) { $request in
            RootView(locations: locations, request: $request)
                .preferredColorScheme(TestRun.isDark ? .dark : nil)
        } defaultValue: {
            WindowRequest()
        }
        .commands { TreewiseCommands() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { locations.save() }
            // In the background the folders are not watched, as iOS asks of file
            // presenters; back in front, what changed meanwhile is read (ADR 0120).
            switch phase {
            case .background:
                locations.pauseWatching()
                IPadSync.pause()
            case .active:
                Task {
                    await locations.resumeWatching()
                    await IPadSync.resume()
                }
            default: break
            }
        }
    }
}
