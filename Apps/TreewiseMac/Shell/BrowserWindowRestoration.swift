import AppKit
import TreewiseUI

/// Builds a browser window again from the state AppKit kept of it, at the next
/// launch (ADR 0083). AppKit puts it back in its place, size and tab group.
final class BrowserWindowRestoration: NSObject, NSWindowRestoration {
    /// The identifier every browser window has, which AppKit hands back here.
    static let identifier = NSUserInterfaceItemIdentifier("browser")
    /// Where a window keeps its `WindowSnapshot` in its restorable state.
    static let snapshotKey = "snapshot"

    static func restoreWindow(
        withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder,
        completionHandler: @escaping (NSWindow?, (any Error)?) -> Void
    ) {
        let data = state.decodeObject(of: NSData.self, forKey: snapshotKey) as Data?
        let snapshot = data.flatMap { try? JSONDecoder().decode(WindowSnapshot.self, from: $0) }
        MainActor.assumeIsolated {
            completionHandler(WindowTabs.shared.restore(snapshot), nil)
        }
    }

    /// Keeps `snapshot` in a window's restorable state.
    static func encode(_ snapshot: WindowSnapshot, in state: NSCoder) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        state.encode(data as NSData, forKey: snapshotKey)
    }
}
