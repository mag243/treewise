import SwiftUI

@main
struct TreewiseiOSApp: App {
    @State private var locations = Locations()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(locations: locations)
                .task { await locations.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { locations.save() }
            // In the background the folders are not watched, as iOS asks of file
            // presenters; back in front, what changed meanwhile is read (ADR 0120).
            switch phase {
            case .background: locations.browser?.pauseWatching()
            case .active: Task { await locations.browser?.resumeWatching() }
            default: break
            }
        }
    }
}
