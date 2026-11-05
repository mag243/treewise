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
        }
    }
}
