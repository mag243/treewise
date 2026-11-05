import AppKit
import SwiftUI
import TreewiseUI

@main
struct TreewiseMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = BrowserSettings(store: LaunchOptions.settingsStore)
    @StateObject private var updater = AppUpdater()
    /// One clipboard for every window (ADR 0037).
    @State private var clipboard = SharedClipboard()
    /// One undo history of file operations for every window (ADR 0037).
    @State private var undo = SharedUndo()

    init() {
        // Tabs are macOS's window tabs, one folder per window (ADR 0037).
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    var body: some Scene {
        WindowGroup(for: TabRequest.self) { $request in
            BrowserWindow(
                settings: settings, clipboard: clipboard, undoManager: undo.manager,
                request: request)
        }
        // Treewise restores its windows itself, on every Mac (ADR 0038).
        .restorationBehavior(.disabled)
        // The window is no narrower than its content's minimum (ADR 0037).
        .windowResizability(.contentMinSize)
        .commands {
            BrowserCommands()
            UndoCommands(undo: undo)
            UpdateCommands(updater: updater)
        }
        Settings {
            SettingsView(settings: settings, updater: updater)
        }
    }
}
