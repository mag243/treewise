import AppKit
import TreewiseCore
import TreewiseUI

/// Opens a folder in the terminal the settings name (ADR 0052). Opening a
/// folder with an app needs no Automation permission and gives a new window.
@MainActor
enum TerminalOpener {
    /// A terminal Treewise can offer.
    struct App: Identifiable {
        let id: String
        let name: String
    }

    private static let defaultApp = "com.apple.Terminal"
    private static let knownApps = [
        App(id: defaultApp, name: "Terminal"),
        App(id: "com.googlecode.iterm2", name: "iTerm"),
        App(id: "com.mitchellh.ghostty", name: "Ghostty"),
        App(id: "dev.warp.Warp-Stable", name: "Warp"),
        App(id: "net.kovidgoyal.kitty", name: "kitty"),
        App(id: "org.alacritty", name: "Alacritty"),
    ]

    /// Whether a terminal may open: not while confined, because a shell
    /// reaches everything the boundary keeps out (ADR 0019).
    static var isAvailable: Bool { LaunchOptions.boundary == nil }

    /// The known terminals on this Mac.
    static var installedApps: [App] {
        knownApps.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.id) != nil
        }
    }

    /// The setting's terminal when it is installed, else Terminal.
    static func chosenApp(in settings: BrowserSettings) -> String {
        let chosen = settings.terminalApp ?? defaultApp
        return installedApps.contains { $0.id == chosen } ? chosen : defaultApp
    }

    /// Opens `folder` in the chosen terminal; a failure shows an alert.
    static func open(_ folder: FileItem.ID?, settings: BrowserSettings) {
        guard isAvailable, let folder = folder?.diskURL,
            let app = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: chosenApp(in: settings))
        else { return }
        Task {
            do {
                _ = try await NSWorkspace.shared.open(
                    [folder], withApplicationAt: app,
                    configuration: NSWorkspace.OpenConfiguration())
            } catch {
                let alert = NSAlert(error: error)
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
