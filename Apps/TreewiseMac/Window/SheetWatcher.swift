import AppKit
import SwiftUI

extension View {
    /// Keeps `showsSheet` true while the window in `host` shows a sheet, such
    /// as an alert, so the menu bar can leave that window alone until the
    /// sheet is answered, as on every Mac.
    func watchingSheets(of host: WindowHost, showsSheet: Binding<Bool>) -> some View {
        onReceive(NotificationCenter.default.publisher(for: NSWindow.willBeginSheetNotification)) {
            if ($0.object as? NSWindow) === host.window { showsSheet.wrappedValue = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndSheetNotification)) {
            if ($0.object as? NSWindow) === host.window { showsSheet.wrappedValue = false }
        }
    }
}
