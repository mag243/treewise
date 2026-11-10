import AppKit

/// The View menu: icons or list, the details pane, reading the folder again,
/// and the sidebar and toolbar, as AppKit shows and hides them.
@MainActor
enum ViewMenu {
    private typealias Window = BrowserWindowController

    static func make() -> NSMenuItem {
        MenuItem.menu(
            "View",
            [
                MenuItem.make("as Icons", #selector(Window.showAsIcons(_:)), key: "1"),
                MenuItem.make("as List", #selector(Window.showAsList(_:)), key: "2"),
                .separator(),
                MenuItem.make(
                    "Show Details", #selector(Window.toggleDetails(_:)), key: "p",
                    modifiers: [.command, .shift]),
                MenuItem.make("Refresh", #selector(Window.refreshFolder(_:)), key: "r"),
                .separator(),
                MenuItem.make(
                    "Show Sidebar", #selector(NSSplitViewController.toggleSidebar(_:)), key: "s",
                    modifiers: [.command, .control]),
                MenuItem.make(
                    "Hide Toolbar", #selector(NSWindow.toggleToolbarShown(_:)), key: "t",
                    modifiers: [.command, .option]),
            ])
    }
}
